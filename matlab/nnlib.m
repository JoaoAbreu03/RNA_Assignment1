function L = nnlib()
% NNLIB  Biblioteca do projeto (UCI Air Quality). Compativel com MATLAB R2007a.
% Uso:  L = nnlib();   [header, data, isNum] = L.readCSV('AirQualityUCI.csv');

% DataLoader
L.readCSV = @readCSV;
L.dropEmptyRows = @dropEmptyRows;
L.splitDataset = @splitDataset;

% Data Cleaning
L.dropColumns = @dropColumns;
L.removeDuplicates = @removeDuplicates;
L.replaceMissingCode = @replaceMissingCode;
L.dropMissingTarget = @dropMissingTarget;
L.handleMissingValues = @handleMissingValues;
L.removeOutliers = @removeOutliers;
L.clipToLimits = @clipToLimits;

% Data Visualization
L.plotMissingValues = @plotMissingValues;
L.plotCleaningEffect = @plotCleaningEffect;
L.plotOriginalFeatures = @plotOriginalFeatures;
L.plotFeaturesVsTarget = @plotFeaturesVsTarget;
L.plotCorrelationHeatmap = @plotCorrelationHeatmap;

% Data Preprocessing
L.normalizeFeatures = @normalizeFeatures;

% EDA
L.summaryTable = @summaryTable;
L.printSummaryTable = @printSummaryTable;
L.pcaGroups = @pcaGroups;
L.ldaGroups = @ldaGroups;

% Feature Analysis: engenharia de features
L.addTimeFeatures = @addTimeFeatures;
L.addInteractionFeatures = @addInteractionFeatures;
L.copyColumns = @copyColumns;
L.plotFeatureEngineeringEffect = @plotFeatureEngineeringEffect;
L.plotCyclicFeatures = @plotCyclicFeatures;
L.plotEngineeredFeatures = @plotEngineeredFeatures;

% Feature Analysis: selecao de features
L.plotImportanceAll = @plotImportanceAll;
L.selectFeatures = @selectFeatures;
L.applySelection = @applySelection;
L.removeUnimportantFeatures = @removeUnimportantFeatures;

end

% ===================== 1. DATALOADER =====================

function [header, data, isNum] = readCSV(filename)
% Le qualquer CSV e devolve tudo, sem limpar nada.
%   header : 1-by-m cell com os nomes das colunas
%   data   : n-by-m cell (colunas numericas ficam como numeros, o resto como texto)
%   isNum  : 1-by-m logical, true nas colunas numericas
txt = fileread(filename);

% primeira linha = cabecalho
nl   = find(txt == char(10), 1);
if isempty(nl), nl = numel(txt) + 1; end
line = txt(1:nl-1);
line(line == char(13)) = [];

% detetar o separador: o que aparece mais vezes no cabecalho
cands = {';', ',', char(9)};
cnt = zeros(1, 3);
for k = 1:3
    cnt(k) = numel(strfind(line, cands{k}));
end
[mx, idx] = max(cnt);
if mx == 0, delim = ','; else delim = cands{idx}; end
nCols = numel(strfind(line, delim)) + 1;

% virgula decimal 
if ~strcmp(delim, ',')
    txt = strrep(txt, ',', '.');
end

% cabecalho
h = textscan(line, repmat('%s', 1, nCols), 'Delimiter', delim, 'Whitespace', ' \b');
header = cell(1, nCols);
for j = 1:nCols
    if isempty(h{j}), header{j} = ''; else header{j} = h{j}{1}; end
end

% corpo: le tudo como texto
C = textscan(txt, repmat('%s', 1, nCols), 'Delimiter', delim, ...
             'Whitespace', ' \b', 'HeaderLines', 1);
n = max(cellfun(@numel, C));
data  = cell(n, nCols);
isNum = false(1, nCols);
for j = 1:nCols
    col = C{j};
    col(end+1:n, 1) = {''};              % completa colunas mais curtas
    v = str2double(col);                  % texto -> numero (NaN se nao der)
    nonEmpty = ~cellfun('isempty', col);
    if all(~isnan(v(nonEmpty)))           % todas as celulas preenchidas sao numeros
        isNum(j) = true;
        data(:, j) = num2cell(v);
    else
        data(:, j) = col;
    end
end
end

function [data, nRemoved] = dropEmptyRows(data, isNum)
% Remove linhas completamente vazias (colunas numericas NaN e texto vazio).
n = size(data, 1);
empty = true(n, 1);
for j = 1:size(data, 2)
    col = data(:, j);
    if isNum(j)
        empty = empty & isnan(cell2mat(col));
    else
        empty = empty & cellfun('isempty', col);
    end
end
nRemoved = sum(empty);
data = data(~empty, :);
end

function [train, test] = splitDataset(data, trainFraction, shuffle)
% Divide as linhas em treino e teste.
%   shuffle = false -> ordem cronologica: as primeiras linhas sao o treino e as ultimas o teste
%                      (e o certo numa serie temporal; o teste nunca e "o passado" do treino)
%   shuffle = true  -> linhas escolhidas ao acaso
if nargin < 2, trainFraction = 0.7; end
if nargin < 3, shuffle = false; end
n = size(data, 1);
nTr = round(trainFraction * n);
if shuffle
    idx = randperm(n);
else
    idx = 1:n;
end
train = data(idx(1:nTr), :);
test  = data(idx(nTr+1:end), :);
end


% ===================== 2. DATA CLEANING =====================

function [header, data, isNum] = dropColumns(header, data, isNum, cols)
% Remove colunas. cols = nome ('T'), lista de nomes ({'T','RH'}) ou indices ([3 5]).
% Se cols nao for dado, remove as colunas completamente vazias.
nCols = size(data, 2);
drop = false(1, nCols);
if nargin < 4 || isempty(cols)
    for j = 1:nCols
        if isNum(j)
            drop(j) = all(isnan(cell2mat(data(:,j))));
        else
            drop(j) = all(cellfun('isempty', data(:,j)));
        end
    end
else
    if ischar(cols), cols = {cols}; end
    if iscell(cols)
        for k = 1:numel(cols)
            drop = drop | strcmp(header, cols{k});
        end
    else
        drop(cols) = true;
    end
end
header = header(~drop);
data   = data(:, ~drop);
isNum  = isNum(~drop);
end

function [data, nRemoved] = removeDuplicates(data)
% Remove linhas duplicadas (iguais em todas as colunas). Mantem a primeira.
[nObs, nCols] = size(data);
keys = cell(nObs, 1);
for i = 1:nObs
    s = '';
    for j = 1:nCols
        v = data{i,j};
        if ischar(v)
            s = [s v '|'];
        else
            s = [s sprintf('%.10g', v) '|'];
        end
    end
    keys{i} = s;
end
[u, idx] = unique(keys, 'first');
idx = sort(idx);                       % mantem a ordem original
data = data(idx, :);
nRemoved = nObs - numel(idx);
end

function [data, nCodes] = replaceMissingCode(data, isNum, code)
% No Air Quality, -200 significa "sem medicao". Passa a NaN nas colunas numericas.
if nargin < 3, code = -200; end
nCodes = 0;
for j = find(isNum)
    x = cell2mat(data(:, j));
    bad = (x == code);
    nCodes = nCodes + sum(bad);
    x(bad) = NaN;
    data(:, j) = num2cell(x);
end
end

function [data, nRemoved] = dropMissingTarget(header, data, target)
% Remove as linhas sem valor no target (o target nunca e imputado).
j = colIndex(header, target);
bad = isnan(cell2mat(data(:, j)));
nRemoved = sum(bad);
data = data(~bad, :);
end

function [data, nMissing] = handleMissingValues(data, isNum)
% Preenche os NaN das colunas numericas por interpolacao linear no tempo (a serie e
% horaria). Nos extremos usa o valor mais proximo.
%   nMissing : 1-by-p, valores em falta por coluna numerica
idxNum = find(isNum);
X = cell2mat(data(:, idxNum));
nMissing = sum(isnan(X), 1);
t = (1:size(X, 1))';
for j = 1:size(X, 2)
    col = X(:, j);
    ok = ~isnan(col);
    if sum(ok) >= 2
        col = interp1(t(ok), col(ok), t);
        first = find(ok, 1, 'first');
        last  = find(ok, 1, 'last');
        col(1:first-1)  = col(first);
        col(last+1:end) = col(last);
    end
    X(:, j) = col;
end
data(:, idxNum) = num2cell(X);
end

function [data, nAffected, lower, upper] = removeOutliers(data, isNum, k, header, skipCols)
% Outliers pelo metodo IQR: os valores fora de [Q1 - k*IQR, Q3 + k*IQR] sao limitados
% (clip) a esses limites.
%   skipCols (opcional): colunas que nao sao alteradas (ex: o target 'CO(GT)')
%   nAffected : numero de valores alterados
%   lower, upper : limites de cada coluna numerica, para aplicar ao teste com clipToLimits
if nargin < 3, k = 1.5; end
if nargin < 5, skipCols = {}; end
if ischar(skipCols), skipCols = {skipCols}; end
idx = find(isNum);
X = cell2mat(data(:, idx));
p = size(X, 2);
lower = -Inf(1, p);
upper = Inf(1, p);
for j = 1:p
    if ~isempty(skipCols) && any(strcmp(skipCols, header{idx(j)})), continue; end
    v = sort(X(~isnan(X(:, j)), j));
    if isempty(v), continue; end
    q1 = quantile1(v, 0.25);
    q3 = quantile1(v, 0.75);
    lower(j) = q1 - k * (q3 - q1);
    upper(j) = q3 + k * (q3 - q1);
end
nAffected = sum(sum(X < repmat(lower, size(X, 1), 1) | X > repmat(upper, size(X, 1), 1)));
data = clipToLimits(data, isNum, lower, upper);
end

function data = clipToLimits(data, isNum, lower, upper)
% Limita as colunas numericas a limites ja calculados (os do treino), para o teste
% ser tratado com as mesmas regras. lower/upper vem de removeOutliers.
idx = find(isNum);
X = cell2mat(data(:, idx));
for j = 1:size(X, 2)
    col = X(:, j);
    col(col < lower(j)) = lower(j);
    col(col > upper(j)) = upper(j);
    X(:, j) = col;
end
data(:, idx) = num2cell(X);
end


% ===================== 3. DATA VISUALIZATION =====================

function plotMissingValues(header, data, isNum, code)
% Percentagem de valores em falta (o codigo -200 ou NaN) em cada variavel, antes da limpeza.
if nargin < 4, code = -200; end
idx = find(isNum);
p = numel(idx);
pct = zeros(1, p);
for k = 1:p
    x = cell2mat(data(:, idx(k)));
    pct(k) = 100 * mean(x == code | isnan(x));
end
[pct, order] = sort(pct);
names = header(idx(order));
figure('Name', 'Valores em falta', 'Position', [90 70 900 560], 'Color', 'w');
axes('Position', [0.30 0.12 0.65 0.78]);
hold on;
for k = 1:p
    barh(k, pct(k), 0.8, 'FaceColor', featureColor(names{k}));
    text(pct(k), k, sprintf('  %.1f%%', pct(k)), 'FontSize', 9);
end
hold off;
set(gca, 'YTick', 1:p, 'YTickLabel', names, 'YLim', [0 p+1], 'XLim', [0 max(pct) * 1.15 + 1], 'FontSize', 9);
xlabel(sprintf('%% de valores em falta (codigo %g) antes da limpeza', code));
title('Valores em falta por variavel', 'FontSize', 11);
grid on;
end

function plotCleaningEffect(headerRaw, dataRaw, isNumRaw, header, data, isNum, names, code)
% Antes e depois da limpeza para as variaveis indicadas: histograma antes (com os -200),
% histograma depois, e as estatisticas dos dois lados.
if nargin < 8, code = -200; end
n = numel(names);
figure('Name', 'Antes e depois da limpeza', 'Position', [40 30 1250 min(220 * n + 80, 900)], 'Color', 'w');
for k = 1:n
    name = names{k};
    xr = cell2mat(dataRaw(:, colIndex(headerRaw, name)));
    xc = cell2mat(data(:, colIndex(header, name)));
    col = featureColor(name);
    lim = [min([xr; xc]) max([xr; xc])];
    pad = 0.03 * (lim(2) - lim(1));
    lim = lim + [-pad pad];

    subplot(n, 3, 3*(k-1) + 1);
    [cnt, ctr] = hist(xr, 40);
    bar(ctr, cnt, 1, 'FaceColor', [0.55 0.55 0.55], 'EdgeColor', 'w');
    set(gca, 'XLim', lim, 'FontSize', 8);
    title(sprintf('%s - ANTES (%.1f%% = %g)', name, 100 * mean(xr == code), code), 'Interpreter', 'none', 'FontSize', 9);
    ylabel('Frequencia', 'FontSize', 8);

    subplot(n, 3, 3*(k-1) + 2);
    [cnt, ctr] = hist(xc, 40);
    bar(ctr, cnt, 1, 'FaceColor', col, 'EdgeColor', 'w');
    % escala propria: com a do "antes" (que vai ate -200) as barras ficavam esmagadas
    limc = [min(xc) max(xc)] + 0.03 * (max(xc) - min(xc)) * [-1 1];
    if limc(2) > limc(1), set(gca, 'XLim', limc); end
    set(gca, 'FontSize', 8);
    title(sprintf('%s - DEPOIS', name), 'Interpreter', 'none', 'FontSize', 9);

    subplot(n, 3, 3*(k-1) + 3);
    axis off;
    okr = xr(xr ~= code & ~isnan(xr));
    text(0.02, 0.85, sprintf('linhas:   %d  ->  %d', numel(xr), numel(xc)), 'FontSize', 9);
    text(0.02, 0.68, sprintf('media:    %.2f  ->  %.2f', mean(okr), mean(xc)), 'FontSize', 9);
    text(0.02, 0.51, sprintf('desvio:   %.2f  ->  %.2f', std(okr), std(xc)), 'FontSize', 9);
    text(0.02, 0.34, sprintf('minimo:   %.2f  ->  %.2f  (antes: %.0f)', min(okr), min(xc), min(xr)), 'FontSize', 9);
    text(0.02, 0.17, sprintf('maximo:   %.2f  ->  %.2f', max(okr), max(xc)), 'FontSize', 9);
    text(0.02, 0.01, '(estatisticas "antes" sem os -200)', 'FontSize', 7);
end
end

function plotOriginalFeatures(header, data, isNum, target, baseNames)
% Distribuicao das features originais e do target (com plotDistributions).
names = [baseNames(:)' {target}];
idx = zeros(1, numel(names));
for k = 1:numel(names), idx(k) = colIndex(header, names{k}); end
plotDistributions(header(idx), data(:, idx), isNum(idx));
end

function plotDistributions(header, data, isNum)
% Distribuicao de cada variavel numerica (8 por figura): histograma na cor da variavel,
% curva normal cinzenta (mesma media e desvio, para ver o desvio a uma gaussiana) e boxplot
% por baixo com o numero de outliers (1.5*IQR).
% O titulo mostra a assimetria (skew); fica a vermelho quando |skew| > 1.
perFigure = 8;
idx = find(isNum);
nFig = ceil(numel(idx) / perFigure);
for f = 1:nFig
    chunk = (f-1)*perFigure + 1 : min(f*perFigure, numel(idx));
    figure('Name', sprintf('Distribuicoes %d/%d', f, nFig), 'Position', [30 30 1250 760], 'Color', 'w');
    for k = 1:numel(chunk)
        j = idx(chunk(k));
        name = header{j};
        x = cell2mat(data(:, j));
        x = x(~isnan(x));
        col = featureColor(name);
        sk = skew1(x);
        r = floor((k-1) / 4);  c = mod(k-1, 4);
        left = 0.05 + c * 0.24;  top = 0.88 - r * 0.46;
        if abs(sk) > 1, tcol = [0.7 0.1 0.1]; tstr = ' (forte)'; else tcol = [0 0 0]; tstr = ''; end

        axes('Position', [left, top - 0.27, 0.20, 0.22]);
        [cnt, ctr] = hist(x, 30);
        bar(ctr, cnt, 1, 'FaceColor', col, 'EdgeColor', 'w');
        xl = [min(x) max(x)];
        pad = 0.03 * (xl(2) - xl(1));
        xl = xl + [-pad pad];
        hold on;
        xg = linspace(xl(1), xl(2), 200);
        sd = std(x);
        bw = ctr(2) - ctr(1);
        plot(xg, numel(x) * bw * exp(-0.5 * ((xg - mean(x)) / sd).^2) / (sd * sqrt(2*pi)), ...
             '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);
        hold off;
        set(gca, 'XLim', xl, 'XTickLabel', [], 'FontSize', 8);
        title({name, sprintf('assimetria = %.2f%s', sk, tstr)}, 'Interpreter', 'none', 'FontSize', 9, 'Color', tcol);
        ylabel('Frequencia', 'FontSize', 8);

        axes('Position', [left, top - 0.37, 0.20, 0.07]);
        s = boxStats(x);
        hold on;
        drawBox(s, 1, col, true, 0.35, true);
        hold off;
        set(gca, 'XLim', xl, 'YLim', [0 2], 'YTick', [], 'FontSize', 8);
        xlabel(sprintf('%d outliers (1.5*IQR)', numel(s.out)), 'FontSize', 8);
    end
    axes('Position', [0 0.95 1 0.05], 'Visible', 'off');
    text(0.5, 0.5, sprintf('Distribuicao das variaveis - figura %d/%d   (cinzento = curva normal)', f, nFig), ...
         'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');
end
end

function plotFeaturesVsTarget(header, data, isNum, target, topK)
% Scatter das topK features mais correlacionadas com o target, com reta de ajuste.
if nargin < 5, topK = 6; end
y = cell2mat(data(:, colIndex(header, target)));
idx = find(isNum & ~strcmp(header, target));
r = zeros(1, numel(idx));
for k = 1:numel(idx), r(k) = corrPair(cell2mat(data(:, idx(k))), y); end
[ss, order] = sort(abs(r), 'descend');
topK = min(topK, numel(idx));
rand('state', 0);
sel = randperm(numel(y));
sel = sel(1:min(2500, numel(y)));
figure('Name', 'Features vs target', 'Position', [50 50 1200 650], 'Color', 'w');
for q = 1:topK
    j = idx(order(q));
    x = cell2mat(data(:, j));
    subplot(2, 3, q);
    plot(x(sel), y(sel), '.', 'Color', featureColor(header{j}), 'MarkerSize', 6);
    hold on;
    pf = polyfit(x, y, 1);
    xg = linspace(min(x), max(x), 50);
    plot(xg, polyval(pf, xg), 'k-', 'LineWidth', 2);
    hold off;
    xlabel(header{j}, 'Interpreter', 'none', 'FontSize', 9);
    ylabel(target, 'Interpreter', 'none', 'FontSize', 9);
    title(sprintf('r = %.2f', r(order(q))), 'FontSize', 10);
    grid on;
end
end

function plotCorrelationHeatmap(header, data, isNum, titleStr)
% Mapa de calor da correlacao de Pearson entre todas as variaveis numericas.
if nargin < 4, titleStr = 'Matriz de correlacao entre features e target'; end
idx = find(isNum);
names = header(idx);
C = corrMatrix(cell2mat(data(:, idx)));
p = numel(names);
figure('Name', 'Matriz de correlacao', 'Position', [60 40 1100 850], 'Color', 'w');
axes('Position', [0.27 0.25 0.62 0.67]);
imagesc(C, [-1 1]);
colormap(bwrMap(64));
colorbar;
set(gca, 'XTick', 1:p, 'XTickLabel', [], 'YTick', 1:p, 'YTickLabel', names, 'FontSize', 8);
for i = 1:p
    for j = 1:p
        text(j, i, sprintf('%.2f', C(i,j)), 'HorizontalAlignment', 'center', 'FontSize', 6);
    end
end
for j = 1:p
    text(j, p + 0.8, names{j}, 'Rotation', 90, 'HorizontalAlignment', 'right', ...
         'FontSize', 8, 'Interpreter', 'none');
end
title(titleStr, 'FontSize', 11);
end

function plotImportance(names, imp, titleStr)
% Barras horizontais com a importancia de cada feature (cor propria, valor ao lado).
[imp, order] = sort(imp);
names = names(order);
p = numel(names);
figure('Name', titleStr, 'Position', [80 60 1000 650], 'Color', 'w');
axes('Position', [0.38 0.10 0.57 0.82]);
hold on;
for i = 1:p
    barh(i, imp(i), 0.8, 'FaceColor', featureColor(names{i}));
    text(imp(i), i, sprintf('  %.4f', imp(i)), 'FontSize', 8);
end
hold off;
set(gca, 'YTick', 1:p, 'YTickLabel', names, 'YLim', [0 p+1], 'FontSize', 8);
xlabel('Importancia por permutacao (queda do R2)');
title(titleStr, 'Interpreter', 'none');
end

function c = featureColor(name)
% Cada feature tem sempre a mesma cor em todos os graficos (registo persistente).
persistent names;
if isempty(names), names = {}; end
k = find(strcmp(names, name), 1);
if isempty(k)
    names{end+1} = name;
    k = numel(names);
end
pal = [hsv(20); hsv(20) * 0.65];            % 40 cores
pal = pal(mod((0:39) * 17, 40) + 1, :);     % baralha, para cores vizinhas serem diferentes
c = pal(mod(k-1, 40) + 1, :);
end

function c = groupColors()
% Cores dos 3 grupos de CO: baixo (azul), medio (laranja), alto (vermelho).
c = [0.15 0.45 0.85; 0.95 0.65 0.10; 0.85 0.15 0.15];
end

function cmap = bwrMap(n)
% Mapa de cores azul - branco - vermelho.
h = floor(n / 2);
cmap = [linspace(0,1,h)' linspace(0,1,h)' ones(h,1); ...
        ones(n-h,1) linspace(1,0,n-h)' linspace(1,0,n-h)'];
end

function s = boxStats(v)
% Estatisticas de um boxplot (regra 1.5*IQR).
v = sort(v(~isnan(v)));
s.q1 = quantile1(v, 0.25);  s.med = quantile1(v, 0.5);  s.q3 = quantile1(v, 0.75);
iqr = s.q3 - s.q1;
isOut = v < s.q1 - 1.5*iqr | v > s.q3 + 1.5*iqr;
s.lo = min(v(~isOut));  s.hi = max(v(~isOut));
s.out = v(isOut);
end

function drawBox(s, pos, col, horizontal, w, showOut)
% Desenha uma caixa (sem precisar da Statistics Toolbox).
if horizontal
    patch([s.q1 s.q3 s.q3 s.q1], [pos-w pos-w pos+w pos+w], col, 'EdgeColor', 'k');
    line([s.med s.med], [pos-w pos+w], 'Color', 'k', 'LineWidth', 2);
    line([s.lo s.q1], [pos pos], 'Color', 'k');
    line([s.q3 s.hi], [pos pos], 'Color', 'k');
    if showOut && ~isempty(s.out)
        line(s.out, pos * ones(size(s.out)), 'LineStyle', 'none', 'Marker', '.', 'MarkerSize', 4, 'Color', 'k');
    end
else
    patch([pos-w pos+w pos+w pos-w], [s.q1 s.q1 s.q3 s.q3], col, 'EdgeColor', 'k');
    line([pos-w pos+w], [s.med s.med], 'Color', 'k', 'LineWidth', 2);
    line([pos pos], [s.lo s.q1], 'Color', 'k');
    line([pos pos], [s.q3 s.hi], 'Color', 'k');
    if showOut && ~isempty(s.out)
        line(pos * ones(size(s.out)), s.out, 'LineStyle', 'none', 'Marker', '.', 'MarkerSize', 4, 'Color', 'k');
    end
end
end

function drawEllipse(P, col)
% Elipse com 1.5 desvios-padrao a volta do centro do grupo (mostra onde esta a maioria).
mu = mean(P, 1);
C = cov(P);
[V, D] = eig(C);
t = linspace(0, 2*pi, 100);
pts = V * sqrt(abs(D)) * [cos(t); sin(t)] * 1.5;
line(mu(1) + pts(1, :), mu(2) + pts(2, :), 'Color', col, 'LineWidth', 2);
end

function s = shortName(name)
% Nome curto e legivel de uma feature para os graficos, ex:
%   'PT08.S1(CO)_x_T'                          -> 'sensor CO x temperatura'
%   'merge[C6H6(GT)+PT08.S2(NMHC)+PT08.S5(O3)]' -> 'juncao: C6H6 + PT08.S2(NMHC) + PT08.S5(O3)'
if strncmp(name, 'merge[', 6) && name(end) == ']'
    s = 'juncao: ';
    rest = name(7:end-1);
    p = find(rest == '+', 1);
    while ~isempty(p)
        s = [s shortSensor(rest(1:p-1)) ' + '];
        rest = rest(p+1:end);
        p = find(rest == '+', 1);
    end
    s = [s shortSensor(rest)];
elseif ~isempty(strfind(name, '_x_'))
    k = strfind(name, '_x_');
    s = [shortSensor(name(1:k-1)) ' x ' shortMod(name(k+3:end))];
else
    s = shortMod(strrep(name, '(GT)', ''));
end
end

function s = shortSensor(name)
if strcmp(name, 'PT08.S1(CO)'), s = 'sensor CO'; else s = strrep(name, '(GT)', ''); end
end

function s = shortMod(name)
switch name
    case 'T',  s = 'temperatura';
    case 'RH', s = 'humidade';
    case 'AH', s = 'humidade absoluta';
    otherwise, s = name;
end
end


% ===================== 4. DATA PREPROCESSING =====================

function [data, params] = normalizeFeatures(data, header, isNum, numCols, params)
% StandardScaler: (x - media) / desvio (desvio populacional, como o sklearn).
%   numCols : nomes das colunas a normalizar (o target NAO deve estar aqui)
%   params  : (opcional) devolvido por uma chamada anterior. Se dado, aplica a media e o
%             desvio ja calculados (no treino), como o transform do sklearn.
% NaN sao ignorados no calculo e continuam NaN.
fit = (nargin < 5 || isempty(params));
if fit
    params.numCols = numCols;
    params.mean = zeros(1, numel(numCols));
    params.std  = ones(1, numel(numCols));
end
for k = 1:numel(params.numCols)
    j = colIndex(header, params.numCols{k});
    if ~isNum(j), error(['So e possivel normalizar colunas numericas: ' header{j}]); end
    x  = cell2mat(data(:, j));
    ok = ~isnan(x);
    if fit && any(ok)
        params.mean(k) = mean(x(ok));
        s = std(x(ok), 1);                 % 1 = desvio populacional
        if s == 0, s = 1; end              % coluna constante (como o sklearn)
        params.std(k) = s;
    end
    data(:, j) = num2cell((x - params.mean(k)) / params.std(k));
end
end

% ===================== 5. EDA (estatisticas, PCA e LDA) =====================

function T = summaryTable(header, data, isNum, target)
% Estatisticas de cada variavel numerica (features e target) e correlacoes com o target.
idx = find(isNum);
X = cell2mat(data(:, idx));
y = cell2mat(data(:, colIndex(header, target)));
p = size(X, 2);
T.names = header(idx);
T.columns = {'count','mean','std','min','25%','50%','75%','max','skew','pearson','spearman'};
T.stats = zeros(p, 11);
for j = 1:p
    x = X(:, j);
    v = sort(x(~isnan(x)));
    T.stats(j, :) = [numel(v), mean(v), std(v), v(1), quantile1(v,0.25), quantile1(v,0.5), ...
                     quantile1(v,0.75), v(end), skew1(v), corrPair(x, y), spearmanPair(x, y)];
end
end

function printSummaryTable(T)
fprintf('%-34s', 'variavel');
fprintf(' %9s', T.columns{:});
fprintf('\n');
for j = 1:numel(T.names)
    fprintf('%-34s', T.names{j});
    fprintf(' %9.3f', T.stats(j, :));
    fprintf('\n');
end
end

function res = pcaGroups(header, data, isNum, target, excludeCols)
% PCA das variaveis certas (continuas, sem o target), com os pontos coloridos pelos 3 grupos
% de CO. Mostra quanto os grupos se separam: % de pontos que ficam mais perto do centro do
% seu proprio grupo. O PCA nao usa o CO para calcular os eixos (nao e supervisionado).
if nargin < 5, excludeCols = {}; end
names = pcaFeatureNames(header, data, isNum, target, excludeCols);
X = getFeatures(header, data, names);
y = cell2mat(data(:, colIndex(header, target)));
Z = standardize(X);
[U, S, V] = svd(Z, 0);
s2 = diag(S).^2;
expl = s2 / sum(s2);
P = Z * V(:, 1:2);
[cls, labels, cuts] = makeGroups(y);
[acc, conf, cent] = nearestCentroid(P, cls);

fprintf('\nPCA com %d variaveis: %s\n', numel(names), joinStrings(names, ', '));
fprintf('  variancia explicada: PC1 %.1f%% | PC2 %.1f%% | total %.1f%%\n', 100*expl(1), 100*expl(2), 100*sum(expl(1:2)));
fprintf('  pontos mais perto do centro do seu grupo de CO: %.1f%%\n', 100 * acc);
printConfusion(conf, labels);

res.names = names;  res.explained = expl;  res.loadings = V;
res.scores = P;  res.groups = cls;  res.accuracy = acc;  res.conf = conf;

col = groupColors();
figure('Name', 'PCA - 3 grupos de CO', 'Position', [60 50 1150 650], 'Color', 'w');
axes('Position', [0.06 0.12 0.58 0.78]);
hold on;
hc = zeros(1, 3);
for g = 1:3
    idx = find(cls == g);
    hc(g) = plot(P(idx, 1), P(idx, 2), '.', 'Color', col(g, :), 'MarkerSize', 8);
end
for g = 1:3
    drawEllipse(P(cls == g, :), col(g, :) * 0.7);
    plot(cent(g, 1), cent(g, 2), 'o', 'MarkerFaceColor', col(g, :), 'MarkerEdgeColor', 'k', 'MarkerSize', 11);
end
% setas das variaveis que mais pesam (sem repetir direcoes iguais)
strength = sqrt(V(:,1).^2 + V(:,2).^2);
[ss, order] = sort(strength, 'descend');
top = [];
for q = 1:numel(order)
    j = order(q);
    similar = false;
    for i = top
        if (V(j,1)*V(i,1) + V(j,2)*V(i,2)) / (strength(j) * strength(i) + 1e-12) > 0.9
            similar = true;
        end
    end
    if ~similar, top(end+1) = j; end
    if numel(top) == 5, break; end
end
sc = 0.8 * min(max(abs(P(:,1))), max(abs(P(:,2)))) / max(strength);
for j = top
    cf = featureColor(names{j});
    line([0 V(j,1)*sc], [0 V(j,2)*sc], 'Color', cf, 'LineWidth', 3);
    text(V(j,1)*sc*1.1, V(j,2)*sc*1.1, shortName(names{j}), 'Color', cf, 'FontWeight', 'bold', ...
         'FontSize', 9, 'Interpreter', 'none', 'BackgroundColor', 'w');
end
hold off;
legend(hc, labels, 'Location', 'NorthWest');
xlabel(sprintf('Componente Principal 1 (%.1f%% da variancia)', 100 * expl(1)));
ylabel(sprintf('Componente Principal 2 (%.1f%% da variancia)', 100 * expl(2)));
title({'PCA - os 3 grupos de CO(GT)', ...
       sprintf('%.0f%% dos pontos ficam mais perto do centro do seu grupo (circulo = centro, elipse = 1.5 desvios)', 100 * acc)}, ...
      'Interpreter', 'none', 'FontSize', 10);
grid on;

for pc = 1:2
    axes('Position', [0.72, 0.58 - (pc-1)*0.46, 0.25, 0.30]);
    ctr = linspace(min(P(:, pc)), max(P(:, pc)), 30);
    hold on;
    for g = 1:3
        cnt = hist(P(cls == g, pc), ctr);
        plot(ctr, cnt, '-', 'Color', col(g, :), 'LineWidth', 2);
    end
    hold off;
    xlabel(sprintf('PC%d', pc));
    ylabel('Frequencia');
    title(sprintf('Distribuicao de PC%d por grupo', pc), 'FontSize', 10);
    grid on;
end

% pesos de PC1 e PC2 na consola
fprintf('  pesos (PC1 | PC2):\n');
for i = 1:numel(names)
    fprintf('    %-34s %+.2f | %+.2f\n', shortName(names{i}), V(i, 1), V(i, 2));
end
end

function res = ldaGroups(header, data, isNum, target, excludeCols)
% LDA (analise discriminante linear): os 2 eixos que MELHOR separam os 3 grupos de CO.
% Ao contrario do PCA, usa os grupos para calcular os eixos (e supervisionado), por isso
% mostra o maximo de separacao que uma combinacao linear destas variaveis consegue dar.
if nargin < 5, excludeCols = {}; end
names = pcaFeatureNames(header, data, isNum, target, excludeCols);
X = getFeatures(header, data, names);
y = cell2mat(data(:, colIndex(header, target)));
Z = standardize(X);
[cls, labels, cuts] = makeGroups(y);
n = size(Z, 1);  p = size(Z, 2);
mu = mean(Z, 1);
Sw = zeros(p);  Sb = zeros(p);
for g = 1:3
    Zg = Z(cls == g, :);
    ng = size(Zg, 1);
    mg = mean(Zg, 1);
    D = bsxfun(@minus, Zg, mg);
    Sw = Sw + D' * D;
    Sb = Sb + ng * (mg - mu)' * (mg - mu);
end
[V, E] = eig(Sw \ Sb);
[ev, ord] = sort(real(diag(E)), 'descend');
W = real(V(:, ord(1:2)));
for k = 1:2
    W(:, k) = W(:, k) / sqrt(W(:, k)' * (Sw / (n - 3)) * W(:, k));   % variancia 1 dentro dos grupos
end
P = Z * W;
[acc, conf, cent] = nearestCentroid(P, cls);

fprintf('\nLDA com %d variaveis (2 eixos que melhor separam os 3 grupos):\n', p);
fprintf('  pontos mais perto do centro do seu grupo de CO: %.1f%%\n', 100 * acc);
printConfusion(conf, labels);

res.names = names;  res.scores = P;  res.groups = cls;  res.accuracy = acc;  res.conf = conf;

col = groupColors();
figure('Name', 'LDA - 3 grupos de CO', 'Position', [70 60 900 600], 'Color', 'w');
hold on;
hc = zeros(1, 3);
for g = 1:3
    idx = find(cls == g);
    hc(g) = plot(P(idx, 1), P(idx, 2), '.', 'Color', col(g, :), 'MarkerSize', 8);
end
for g = 1:3
    drawEllipse(P(cls == g, :), col(g, :) * 0.7);
    plot(cent(g, 1), cent(g, 2), 'o', 'MarkerFaceColor', col(g, :), 'MarkerEdgeColor', 'k', 'MarkerSize', 11);
end
hold off;
legend(hc, labels, 'Location', 'NorthWest');
xlabel('Eixo discriminante 1');
ylabel('Eixo discriminante 2');
title({'LDA - melhor separacao linear dos 3 grupos de CO(GT)', ...
       sprintf('%.0f%% dos pontos ficam mais perto do centro do seu grupo', 100 * acc)}, ...
      'Interpreter', 'none', 'FontSize', 10);
grid on;
end

function names = pcaFeatureNames(header, data, isNum, target, excludeCols)
% Variaveis para o PCA/LDA: continuas (mais de 15 valores distintos), sem o target e sem
% as colunas em excludeCols. As discretas (ex: Hour_sin, DayOfWeek_sin) ficam de fora.
if nargin < 5, excludeCols = {}; end
if ischar(excludeCols), excludeCols = {excludeCols}; end
cand = header(isNum & ~strcmp(header, target));
names = {};
for k = 1:numel(cand)
    if any(strcmp(excludeCols, cand{k})), continue; end
    x = cell2mat(data(:, colIndex(header, cand{k})));
    if numel(unique(round(x * 1e6))) <= 15, continue; end
    names{end+1} = cand{k};
end
end

function [cls, labels, cuts] = makeGroups(y)
% Divide o target em 3 grupos do mesmo tamanho (tercis): baixo, medio e alto.
v = sort(y(~isnan(y)));
cuts = [quantile1(v, 1/3), quantile1(v, 2/3)];
cls = ones(size(y));
cls(y > cuts(1)) = 2;
cls(y > cuts(2)) = 3;
labels = {sprintf('baixo (<= %.1f)', cuts(1)), ...
          sprintf('medio (%.1f a %.1f)', cuts(1), cuts(2)), ...
          sprintf('alto (> %.1f)', cuts(2))};
end

function Z = standardize(X)
sd = std(X, 1);
sd(sd == 0) = 1;
Z = bsxfun(@rdivide, bsxfun(@minus, X, mean(X)), sd);
end

function [acc, conf, cent] = nearestCentroid(P, cls)
% Atribui cada ponto ao grupo do centroide mais proximo (no espaco P).
% acc = % certa; conf = matriz de confusao (linhas = grupo real, colunas = previsto).
k = 3;
cent = zeros(k, size(P, 2));
for g = 1:k
    cent(g, :) = mean(P(cls == g, :), 1);
end
d = zeros(size(P, 1), k);
for g = 1:k
    diff = bsxfun(@minus, P, cent(g, :));
    d(:, g) = sum(diff.^2, 2);
end
[ignorar, pred] = min(d, [], 2);
acc = mean(pred == cls);
conf = accumarray([cls pred], 1, [k k]);
end

function printConfusion(conf, labels)
fprintf('\n  Matriz de confusao (linhas = grupo real, colunas = grupo previsto, em %%):\n');
fprintf('  %-22s', '');
for g = 1:3, fprintf(' %-22s', labels{g}); end
fprintf('\n');
for g = 1:3
    fprintf('  %-22s', labels{g});
    fprintf(' %-22.1f', 100 * conf(g, :) / sum(conf(g, :)));
    fprintf('\n');
end
end


% ===================== 6. FEATURE ANALYSIS - ENGENHARIA DE FEATURES =====================

function [header, data, isNum] = appendColumn(header, data, isNum, name, values)
% Acrescenta uma coluna numerica no fim.
header{end+1} = name;
data(:, end+1) = num2cell(values(:));
isNum(end+1) = true;
end

function [header, data, isNum] = addTimeFeatures(header, data, isNum, dateName, timeName)
% Features temporais a partir de Date (dd/mm/aaaa) e Time (hh.mm.ss):
%   Hour_sin, Hour_cos (periodo 24 h) e DayOfWeek_sin, DayOfWeek_cos (periodo 7 dias),
%   para as 23h ficarem perto das 0h e o domingo perto da segunda.
%   Hour e DayOfWeek (0 = segunda) sao auxiliares para os graficos.
% Calculadas linha a linha, por isso nao ha fuga de informacao entre treino e teste.
if nargin < 4, dateName = 'Date'; end
if nargin < 5, timeName = 'Time'; end
d = data(:, colIndex(header, dateName));
t = data(:, colIndex(header, timeName));
n = numel(d);
hour = NaN(n, 1);  dow = NaN(n, 1);
for i = 1:n
    % Normaliza o formato da data substituindo pontos e tracos por barras
    strDate = strrep(strrep(d{i}, '.', '/'), '-', '/');
    a = sscanf(strDate, '%d/%d/%d');          % dia, mes, ano

    strTime = strrep(t{i}, ':', '.');         % garante que a hora usa ponto
    b = sscanf(strTime, '%d.%d.%d');          % hora, minuto, segundo

    if numel(a) == 3 && ~isempty(b)
        hour(i)  = b(1);
        dow(i)   = mod(weekday(datenum(a(3), a(2), a(1))) - 2, 7);
    end
end
[header, data, isNum] = appendColumn(header, data, isNum, 'Hour', hour);
[header, data, isNum] = appendColumn(header, data, isNum, 'DayOfWeek', dow);
[header, data, isNum] = appendColumn(header, data, isNum, 'Hour_sin', sin(2*pi*hour/24));
[header, data, isNum] = appendColumn(header, data, isNum, 'Hour_cos', cos(2*pi*hour/24));
[header, data, isNum] = appendColumn(header, data, isNum, 'DayOfWeek_sin', sin(2*pi*dow/7));
[header, data, isNum] = appendColumn(header, data, isNum, 'DayOfWeek_cos', cos(2*pi*dow/7));
end

function [header, data, isNum] = addInteractionFeatures(header, data, isNum, cols)
% Produto da 1a coluna (o sensor) com cada uma das outras.
% Ex: {'PT08.S1(CO)','T','RH'} -> PT08.S1(CO)_x_T e PT08.S1(CO)_x_RH.
x = cell2mat(data(:, colIndex(header, cols{1})));
for j = 2:numel(cols)
    y = cell2mat(data(:, colIndex(header, cols{j})));
    [header, data, isNum] = appendColumn(header, data, isNum, [cols{1} '_x_' cols{j}], x .* y);
end
end


function [header, data, isNum] = copyColumns(header, data, isNum, headerSrc, dataSrc, names)
% Copia colunas (por nome) de outro conjunto com as mesmas linhas, para o fim.
for k = 1:numel(names)
    j = colIndex(headerSrc, names{k});
    [header, data, isNum] = appendColumn(header, data, isNum, names{k}, cell2mat(dataSrc(:, j)));
end
end

function [r2, yv, pv, val] = fitLinearVal(X, y, seed)
% Regressao linear treinada em 70% dos dados; devolve o R2 nos outros 30% (e as previsoes).
rand('state', seed);
n = size(X, 1);
idx = randperm(n);
nFit = round(0.70 * n);
fit = idx(1:nFit);
val = idx(nFit+1:end);
theta = [ones(nFit, 1) X(fit, :)] \ y(fit);
yv = y(val);
pv = [ones(numel(val), 1) X(val, :)] * theta;
r2 = r2score(yv, pv);
end

function res = plotFeatureEngineeringEffect(header, data, isNum, target, baseNames, groups, groupLabels)
% O que a engenharia de features mudou? (modelo linear, validacao 70/30 no treino)
%  esquerda: R2 so com as originais e a medida que se juntam os grupos de features novas
%  direita: CO medio por hora: real vs modelo so com as originais vs modelo com as novas
% groups = cell de cells com os nomes das features novas de cada grupo.
% Tem de ser chamada antes de remover a coluna Hour.
y = cell2mat(data(:, colIndex(header, target)));
nG = numel(groups);
gcol = [0.20 0.55 0.85; 0.85 0.20 0.20; 0.35 0.70 0.35; 0.70 0.35 0.75];

% R2 cumulativo
r2 = zeros(1, nG + 1);
cur = baseNames;
[r2(1), yv, pBase, val] = fitLinearVal(getFeatures(header, data, cur), y, 0);
pFull = pBase;
for g = 1:nG
    cur = [cur groups{g}];
    [r2(g+1), yv, pFull, val] = fitLinearVal(getFeatures(header, data, cur), y, 0);
end
rmse = [sqrt(mean((yv - pBase).^2)), sqrt(mean((yv - pFull).^2))];
lab = [{sprintf('%d originais', numel(baseNames))} groupLabels];

fprintf('\nEfeito da engenharia de features (modelo linear, R2 de validacao):\n');
for k = 1:numel(r2)
    if k == 1
        fprintf('  %-40s R2 = %.4f\n', lab{k}, r2(k));
    else
        fprintf('  %-40s R2 = %.4f  (%+.4f)\n', lab{k}, r2(k), r2(k) - r2(k-1));
    end
end
fprintf('  RMSE no CO: %.3f -> %.3f\n', rmse(1), rmse(2));

figure('Name', 'Efeito da engenharia de features', 'Position', [40 60 1300 520], 'Color', 'w');

% R2 a medida que se juntam as features novas
subplot(1, 2, 1);
hold on;
for k = 1:numel(r2)
    if k == 1
        cb = [0.6 0.6 0.6];
        txt = sprintf('%.4f', r2(k));
    else
        cb = gcol(mod(k - 2, 4) + 1, :);
        txt = sprintf('%.4f (%+.4f)', r2(k), r2(k) - r2(k-1));
    end
    bar(k, r2(k), 0.6, 'FaceColor', cb);
    text(k, r2(k), txt, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
end
hold off;
set(gca, 'XTick', 1:numel(r2), 'XTickLabel', lab, 'XLim', [0.4 numel(r2) + 0.6], ...
    'YLim', [min(r2) - 0.02, max(r2) + 0.012], 'FontSize', 8);
ylabel('R^2 (modelo linear, validacao)');
title('Quanto as features novas melhoram a previsao do CO', 'FontSize', 10);
grid on;

% perfil por hora
subplot(1, 2, 2);
if any(strcmp(header, 'Hour'))
    hrs = cell2mat(data(val, colIndex(header, 'Hour')));
    hu = unique(hrs);
    mReal = zeros(1, numel(hu));  mBase = mReal;  mFull = mReal;
    for k = 1:numel(hu)
        s = (hrs == hu(k));
        mReal(k) = mean(yv(s));  mBase(k) = mean(pBase(s));  mFull(k) = mean(pFull(s));
    end
    hold on;
    plot(hu, mReal, 'k-o', 'LineWidth', 2.5, 'MarkerFaceColor', 'k');
    plot(hu, mBase, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 2);
    plot(hu, mFull, '-', 'Color', [0.85 0.2 0.2], 'LineWidth', 2);
    hold off;
    legend('CO real', sprintf('modelo so com as originais (erro medio %.2f)', rmse(1)), ...
           sprintf('modelo com as features novas (erro medio %.2f)', rmse(2)), 'Location', 'NorthWest');
    set(gca, 'XLim', [-0.5 23.5], 'XTick', 0:3:21, 'XTickLabel', {'0h','3h','6h','9h','12h','15h','18h','21h'});
    xlabel('Hora do dia');
    ylabel([target ' medio (mg/m3)']);
    title('CO medio ao longo do dia: real vs previsto', 'FontSize', 10);
    grid on;
else
    axis off;
    text(0.1, 0.5, 'Coluna Hour nao encontrada: chama esta funcao antes de a remover.');
end

res.r2 = r2;  res.rmse = rmse;  res.labels = lab;
end

function plotCyclicFeatures(header, data, isNum, target)
% CO medio de cada hora e ajuste com seno/cosseno (1 e 2 ondas por dia, com o R2).
% Para o dia da semana so escreve o R2 do ajuste na consola. Precisa de Hour e DayOfWeek.
y = cell2mat(data(:, colIndex(header, target)));
cols   = {'Hour', 'DayOfWeek'};
period = [24 7];
cats   = {0:23, 0:6};
figure('Name', 'Hora do dia como ciclo', 'Position', [40 60 800 520], 'Color', 'w');
for k = 1:2
    x = cell2mat(data(:, colIndex(header, cols{k})));
    m = NaN(1, numel(cats{k}));
    for q = 1:numel(cats{k})
        s = (x == cats{k}(q));
        if any(s), m(q) = mean(y(s)); end
    end
    xg = linspace(cats{k}(1), cats{k}(end), 200)';
    A  = [ones(numel(x), 1) sin(2*pi*x/period(k)) cos(2*pi*x/period(k))];
    Ag = [ones(200, 1) sin(2*pi*xg/period(k)) cos(2*pi*xg/period(k))];
    th = A \ y;

    if k == 2
        % dia da semana: so o R2 na consola
        fprintf('Dia da semana com seno + cosseno (1 onda): R2 = %.2f\n', r2score(y, A * th));
        continue;
    end
    hold on;
    h = zeros(1, 3);  lab = cell(1, 3);
    h(1) = plot(xg, Ag * th, '-', 'Color', [0.20 0.55 0.85], 'LineWidth', 2.5);
    lab{1} = sprintf('seno + cosseno, 1 onda (R^2 = %.2f)', r2score(y, A * th));
    n = 1;
    if k == 1
        A2 = [A sin(4*pi*x/24) cos(4*pi*x/24)];
        th2 = A2 \ y;
        n = 2;
        h(2) = plot(xg, [Ag sin(4*pi*xg/24) cos(4*pi*xg/24)] * th2, '-', 'Color', [0.85 0.20 0.20], 'LineWidth', 2.5);
        lab{2} = sprintf('2 ondas por dia (R^2 = %.2f)', r2score(y, A2 * th2));
    end
    n = n + 1;
    h(n) = plot(cats{k}, m, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 7);
    lab{n} = 'CO medio real';
    hold off;
    legend(h(1:n), lab(1:n), 'Location', 'NorthWest');
    set(gca, 'XTick', 0:3:21, 'XTickLabel', {'0h','3h','6h','9h','12h','15h','18h','21h'}, 'XLim', [-0.5 23.5]);
    xlabel('Hora do dia');
    title('Hora do dia: picos as 8h e as 19h (transito)', 'FontSize', 10);
    ylabel([target ' medio (mg/m3)']);
    grid on;
end
end

function res = plotEngineeredFeatures(header, data, isNum, target, baseNames)
% Features criadas por nos: o que melhoraram em relacao ao que ja existia.
% Tem de ser chamada antes de remover Hour e DayOfWeek.
%  Figura: ganho de R2 (modelo linear, validacao 70/30) ao juntar cada feature nova as originais;
%     a cinzento a mesma informacao "em numero" (Hour, DayOfWeek), para comparar.
%  Consola: interacoes - quanto o CO sobe por cada +100 no sensor, com temperatura/humidade
%     baixa, media e alta (se os valores forem diferentes, a interacao traz informacao).
y  = cell2mat(data(:, colIndex(header, target)));
Xb = getFeatures(header, data, baseNames);
r2base = fitLinearVal(Xb, y, 0);
famCol = [0.60 0.60 0.60; 0.20 0.55 0.85; 0.35 0.70 0.35; 0.85 0.20 0.20];

% --- 1. ganho de cada feature nova (familia 0 = versao "em numero", so como referencia)
grp = {'hora (numero 0-23)',            {'Hour'},                           0; ...
       'hora: seno + cosseno',          {'Hour_sin', 'Hour_cos'},           1; ...
       'dia da semana (numero 0-6)',    {'DayOfWeek'},                      0; ...
       'dia da semana: seno + cosseno', {'DayOfWeek_sin', 'DayOfWeek_cos'}, 2};
for k = 1:numel(header)
    nm = header{k};
    if ~isempty(strfind(nm, '_x_'))
        grp(end+1, :) = {shortName(nm), {nm}, 3};
    end
end
ok = true(size(grp, 1), 1);                % ignora grupos cujas colunas nao existem
for k = 1:size(grp, 1)
    for q = 1:numel(grp{k, 2})
        if ~any(strcmp(header, grp{k, 2}{q})), ok(k) = false; end
    end
end
grp = grp(ok, :);
nG = size(grp, 1);
gain = zeros(nG, 1);
for k = 1:nG
    gain(k) = fitLinearVal([Xb getFeatures(header, data, grp{k, 2})], y, 0) - r2base;
end
fprintf('\nGanho de R2 de cada feature nova sobre as %d originais (R2 base = %.4f):\n', numel(baseNames), r2base);
for k = 1:nG
    fprintf('  %-40s %+.4f\n', grp{k, 1}, gain(k));
end

figure('Name', 'Features novas: ganho sobre as originais', 'Position', [60 40 1000 620], 'Color', 'w');
axes('Position', [0.30 0.13 0.62 0.78]);
hold on;
for k = 1:nG
    pos = nG + 1 - k;                      % a primeira da lista fica em cima
    barh(pos, gain(k), 0.75, 'FaceColor', famCol(grp{k, 3} + 1, :));
    text(max(gain(k), 0), pos, sprintf('  %+.4f', gain(k)), 'FontSize', 8);
end
hold off;
xl = [min(0, min(gain)) max(gain)];
set(gca, 'YTick', 1:nG, 'YTickLabel', flipud(grp(:, 1)), 'YLim', [0 nG + 1], ...
    'XLim', [xl(1) - 0.05 * (xl(2) - xl(1)), xl(2) * 1.30 + 1e-4], 'FontSize', 8);
xlabel('aumento do R^2 ao juntar a feature as originais (modelo linear, validacao)');
title(sprintf('Features novas: quanto acrescentam as %d originais (R^2 base = %.4f)', numel(baseNames), r2base), 'FontSize', 11);
grid on;
axes('Position', [0 0 1 0.05], 'Visible', 'off');
text(0.5, 0.5, 'cinzento = a mesma informacao dada como numero (referencia) | azul = hora | verde = dia da semana | vermelho = interacoes', ...
     'HorizontalAlignment', 'center', 'FontSize', 8);

% --- 2. interacoes: o efeito do sensor no CO muda com a temperatura e com a humidade?
isInter = ~cellfun('isempty', strfind(header, '_x_'));
prodNames = header(isInter);
r2i = [r2base NaN];
slopes = [];
if ~isempty(prodNames)
    p = strfind(prodNames{1}, '_x_');
    sensor = prodNames{1}(1:p-1);
    mods = {};
    for k = 1:numel(prodNames)
        p = strfind(prodNames{k}, '_x_');
        if strcmp(prodNames{k}(1:p-1), sensor), mods{end+1} = prodNames{k}(p+3:end); end
    end
    xs = cell2mat(data(:, colIndex(header, sensor)));
    slopes = zeros(numel(mods), 3);           % aumento do CO por +100 no sensor, por tercil
    for m = 1:numel(mods)
        mv = cell2mat(data(:, colIndex(header, mods{m})));
        v = sort(mv(~isnan(mv)));
        cuts = [-Inf quantile1(v, 1/3) quantile1(v, 2/3) Inf];
        for t = 1:3
            s = mv > cuts(t) & mv <= cuts(t+1);
            pf = polyfit(xs(s), y(s), 1);
            slopes(m, t) = 100 * pf(1);
        end
    end
    r2i(2) = fitLinearVal([Xb getFeatures(header, data, header(isInter))], y, 0);

    fprintf('\nInteracoes: aumento do CO por +100 no sensor %s (mg/m3), por tercis:\n', sensor);
    tn = {'baixa', 'media', 'alta'};
    for m = 1:numel(mods)
        fprintf('  %-12s', shortName(mods{m}));
        for t = 1:3, fprintf(' %s %.2f |', tn{t}, slopes(m, t)); end
        fprintf('\n');
    end
    fprintf('  R2 de validacao: %.4f sem interacoes -> %.4f com interacoes\n', r2i(1), r2i(2));
end

res.groups = grp(:, 1);  res.gain = gain;  res.r2base = r2base;
res.slopes = slopes;  res.r2inter = r2i;
end


% ===================== 7. FEATURE ANALYSIS - SELECAO DE FEATURES =====================

function plotImportanceAll(header, data, isNum, target)
% Importancia por permutacao de todas as features (modelo linear), antes da selecao.
names = header(isNum & ~strcmp(header, target));
X = getFeatures(header, data, names);
y = cell2mat(data(:, colIndex(header, target)));
[imp, r2] = permutationImportance(X, y, 10, 0);
fprintf('\nModelo linear com todas as features: R2 de validacao = %.3f\n', r2);
plotImportance(names, imp, 'Importancia de todas as features, antes da selecao (modelo linear)');
end

function [header, data, isNum, report] = selectFeatures(header, data, isNum, target, minCorr, minMI, dupThr, mergeThr, keepTogether, mustKeep)
% Selecao de features em 3 passos:
%  1. Irrelevantes: |Pearson| e |Spearman| < minCorr E informacao mutua < minMI.
%  2. Duplicadas: |correlacao| >= dupThr com outra feature (fica a primeira).
%  3. Muito correlacionadas (|r| > mergeThr): cada grupo e substituido por UMA feature
%     nova, a 1a componente principal do grupo, e as originais sao removidas.
% keepTogether (opcional): cell de grupos que so fazem sentido juntos, ex:
%     {{'Hour_sin','Hour_cos'}, {'DayOfWeek_sin','DayOfWeek_cos'}}
%     (o seno sozinho da o mesmo valor a dois pontos do ciclo). Se um do grupo passa o
%     passo 1, ficam todos.
% mustKeep (opcional): features que ficam sempre (nao saem por irrelevantes, duplicadas
%     nem sao juntadas), ex: {'DayOfWeek_sin','DayOfWeek_cos'}.
% report guarda tudo o que foi aprendido, para applySelection repetir a mesma selecao
% noutro conjunto (o teste), incluindo a media, o desvio e os pesos de cada grupo juntado.
if nargin < 5, minCorr = 0.15; end
if nargin < 6, minMI = 0.1; end
if nargin < 7, dupThr = 0.999; end
if nargin < 8, mergeThr = 0.9; end
if nargin < 9, keepTogether = {}; end
if nargin < 10 || isempty(mustKeep), mustKeep = {''}; end    % {''} evita o ismember com cell vazia

y = cell2mat(data(:, colIndex(header, target)));
names = header(isNum & ~strcmp(header, target));
X = getFeatures(header, data, names);
nStart = numel(names);
report.irrelevant = {};  report.duplicates = {};  report.merged = {};  report.merges = {};

% ---- Passo 1: irrelevantes
p = numel(names);
pear = zeros(1, p);  spear = zeros(1, p);  mi = zeros(1, p);
for k = 1:p
    pear(k)  = abs(corrPair(X(:,k), y));
    spear(k) = abs(spearmanPair(X(:,k), y));
    mi(k)    = mutualInfo(X(:,k), y, 10);
end
irrelevant = (max(pear, spear) < minCorr) & (mi < minMI);
for g = 1:numel(keepTogether)
    inGroup = ismember(names, keepTogether{g});
    if any(inGroup & ~irrelevant)
        irrelevant(inGroup) = false;
    end
end
irrelevant(ismember(names, mustKeep)) = false;
fprintf('\nPasso 1 - irrelevantes (|Pearson| e |Spearman| < %.2f e MI < %.2f):\n', minCorr, minMI);
for k = find(irrelevant)
    fprintf('  %-28s pearson=%.3f spearman=%.3f MI=%.3f\n', names{k}, pear(k), spear(k), mi(k));
end
if any(irrelevant)
    report.irrelevant = names(irrelevant);
    [header, data, isNum] = dropColumns(header, data, isNum, names(irrelevant));
    names = names(~irrelevant);
    X = X(:, ~irrelevant);
end

% ---- Passo 2: duplicadas
C = abs(corrMatrix(X));
p = numel(names);
dup = false(1, p);
for i = 1:p
    if dup(i), continue; end
    for j = i+1:p
        if ~dup(j) && C(i,j) >= dupThr, dup(j) = true; end
    end
end
dup(ismember(names, mustKeep)) = false;
fprintf('\nPasso 2 - duplicadas (|r| >= %g): %s\n', dupThr, joinStrings(names(dup), ', '));
if any(dup)
    report.duplicates = names(dup);
    [header, data, isNum] = dropColumns(header, data, isNum, names(dup));
    names = names(~dup);
    X = X(:, ~dup);
end

% ---- Passo 3: grupos muito correlacionados -> uma feature nova por grupo
C = abs(corrMatrix(X));
p = numel(names);
visited = ismember(names, mustKeep);       % as obrigatorias nunca sao juntadas
groups = {};
for s = 1:p
    if visited(s), continue; end
    grp = [];  stack = s;  visited(s) = true;
    while ~isempty(stack)
        a = stack(end);  stack(end) = [];
        grp(end+1) = a;
        for b = 1:p
            if ~visited(b) && C(a,b) > mergeThr
                visited(b) = true;
                stack(end+1) = b;
            end
        end
    end
    if numel(grp) > 1, groups{end+1} = sort(grp); end
end

fprintf('\nPasso 3 - grupos com |r| > %g juntados numa feature nova:\n', mergeThr);
for g = 1:numel(groups)
    grp = groups{g};
    Xg = X(:, grp);
    sd = std(Xg, 1);  sd(sd == 0) = 1;
    Z = bsxfun(@rdivide, bsxfun(@minus, Xg, mean(Xg)), sd);
    [U, S, V] = svd(Z, 0);
    score = Z * V(:,1);
    sgn = 1;
    if corrPair(score, y) < 0, sgn = -1; end              % correlacao positiva com o target
    score = sgn * score;
    rec.name = ['merge[' joinStrings(names(grp), '+') ']'];
    rec.cols = names(grp);
    rec.mean = mean(Xg);
    rec.std = sd;
    rec.v = V(:,1);
    rec.sign = sgn;
    rec.scoreMean = mean(score);
    rec.scoreStd = std(score, 1);
    score = (score - rec.scoreMean) / rec.scoreStd;
    expl = S(1,1)^2 / sum(diag(S).^2);
    fprintf('  %s\n    variancia explicada pela 1a componente: %.1f%% | correlacao com o target: %.3f\n', ...
            rec.name, 100 * expl, abs(corrPair(score, y)));
    [header, data, isNum] = dropColumns(header, data, isNum, names(grp));
    [header, data, isNum] = appendColumn(header, data, isNum, rec.name, score);
    report.merged{end+1} = rec.name;
    report.merges{end+1} = rec;
end

fprintf('\nFeatures numericas: %d -> %d\n', nStart, sum(isNum & ~strcmp(header, target)));
end

function [header, data, isNum] = applySelection(header, data, isNum, report)
% Repete noutro conjunto (o teste) a selecao aprendida no treino por selectFeatures:
% remove as mesmas colunas e cria os mesmos grupos juntados com a media, o desvio e os
% pesos do treino. No fim, as colunas ficam iguais e pela mesma ordem do treino.
if ~isempty(report.irrelevant)
    [header, data, isNum] = dropColumns(header, data, isNum, report.irrelevant);
end
if ~isempty(report.duplicates)
    [header, data, isNum] = dropColumns(header, data, isNum, report.duplicates);
end
for g = 1:numel(report.merges)
    rec = report.merges{g};
    Xg = getFeatures(header, data, rec.cols);
    Z = bsxfun(@rdivide, bsxfun(@minus, Xg, rec.mean), rec.std);
    score = (rec.sign * (Z * rec.v) - rec.scoreMean) / rec.scoreStd;
    [header, data, isNum] = dropColumns(header, data, isNum, rec.cols);
    [header, data, isNum] = appendColumn(header, data, isNum, rec.name, score);
end
end

function [header, data, isNum, removed] = removeUnimportantFeatures(header, data, isNum, target, minImportance, keepTogether, mustKeep)
% Remove as features menos importantes para prever o target.
% Importancia = queda do R2 (modelo linear, num conjunto de validacao) ao baralhar a feature.
% Saem as features com importancia < minImportance (0.005 = queda de 0.5% no R2).
% keepTogether: cell de grupos que so fazem sentido juntos, ex: {{'Hour_sin','Hour_cos'}}
% (o seno sozinho da o mesmo valor a duas horas diferentes). Se um do grupo fica, ficam todos.
% mustKeep (opcional): features que ficam sempre, mesmo com importancia baixa.
if nargin < 5, minImportance = 0.005; end
if nargin < 6, keepTogether = {}; end
if nargin < 7 || isempty(mustKeep), mustKeep = {''}; end     % {''} evita o ismember com cell vazia

names = header(isNum & ~strcmp(header, target));
X = getFeatures(header, data, names);
y = cell2mat(data(:, colIndex(header, target)));
[imp, r2Before] = permutationImportance(X, y, 10, 0);

remove = imp < minImportance;
for g = 1:numel(keepTogether)
    inGroup = ismember(names, keepTogether{g});
    if any(inGroup & ~remove)
        remove(inGroup) = false;
    end
end
remove(ismember(names, mustKeep)) = false;
removed = names(remove);

[ss, order] = sort(imp, 'descend');
fprintf('\nImportancia por permutacao (queda de R2), limiar %g:\n', minImportance);
for k = order
    fprintf('  %-52s %.4f\n', names{k}, imp(k));
end
fprintf('\nRemovidas (%d): %s\n', numel(removed), joinStrings(removed, ', '));

% importancia das features que ficam, recalculada so com elas
[impKept, r2After] = permutationImportance(X(:, ~remove), y, 10, 0);
fprintf('R2 de validacao: %.4f com %d features -> %.4f com %d features\n', ...
        r2Before, numel(names), r2After, sum(~remove));

plotImportance(names(~remove), impKept, 'Importancia das features mantidas, depois da selecao (modelo linear)');
if any(remove)
    [header, data, isNum] = dropColumns(header, data, isNum, removed);
end
end

function [imp, r2] = permutationImportance(X, y, nRepeats, seed)
% Importancia por permutacao com um modelo LINEAR (minimos quadrados):
% treina em 70% dos dados e mede, nos outros 30%, a queda do R2 quando os valores
% de cada feature sao baralhados. Quanto maior a queda, mais a feature importa.
if nargin < 3, nRepeats = 10; end
if nargin < 4, seed = 0; end
rand('state', seed);
n = size(X, 1);
idx = randperm(n);
nFit = round(0.70 * n);
fit = idx(1:nFit);  val = idx(nFit+1:end);
theta = [ones(nFit,1) X(fit,:)] \ y(fit);
Xv = X(val, :);  yv = y(val);  nv = numel(val);
r2 = r2score(yv, [ones(nv,1) Xv] * theta);
imp = zeros(1, size(X, 2));
for j = 1:size(X, 2)
    drops = zeros(1, nRepeats);
    for r = 1:nRepeats
        Xp = Xv;
        Xp(:, j) = Xv(randperm(nv), j);
        drops(r) = r2 - r2score(yv, [ones(nv,1) Xp] * theta);
    end
    imp(j) = mean(drops);
end
end

% ===================== 8. ESTATISTICA (funcoes auxiliares) =====================

function j = colIndex(header, name)
j = find(strcmp(header, name), 1);
if isempty(j), error(['Coluna nao encontrada: ' name]); end
end

function X = getFeatures(header, data, names)
% Matriz n-por-k com as colunas numericas indicadas (por nome).
X = zeros(size(data, 1), numel(names));
for k = 1:numel(names)
    X(:, k) = cell2mat(data(:, colIndex(header, names{k})));
end
end

function q = quantile1(v, p)
% Quantil p (0..1) de um vetor ordenado, com interpolacao linear.
k = numel(v);
pos = 1 + (k-1)*p;
lo = floor(pos);  hi = ceil(pos);
q = v(lo) + (pos - lo) * (v(hi) - v(lo));
end

function s = skew1(x)
% Assimetria (skewness) de um vetor.
x = x(~isnan(x));
sd = std(x, 1);
if sd == 0, s = 0; else s = mean(((x - mean(x)) / sd).^3); end
end

function r = ranks(x)
% Ranks de um vetor coluna; empates ficam com a media dos ranks.
x = x(:);
[sx, ix] = sort(x);
n = numel(x);
r = zeros(n, 1);
i = 1;
while i <= n
    j = i;
    while j < n && sx(j+1) == sx(i), j = j + 1; end
    r(ix(i:j)) = (i + j) / 2;
    i = j + 1;
end
end

function c = corrPair(x, y)
% Correlacao de Pearson (ignora pares com NaN). Coluna constante -> 0.
ok = ~isnan(x) & ~isnan(y);
x = x(ok);  y = y(ok);
sx = std(x, 1);  sy = std(y, 1);
if sx == 0 || sy == 0, c = 0; return; end
c = mean((x - mean(x)) .* (y - mean(y))) / (sx * sy);
end

function c = spearmanPair(x, y)
% Correlacao de Spearman = Pearson dos ranks.
ok = ~isnan(x) & ~isnan(y);
c = corrPair(ranks(x(ok)), ranks(y(ok)));
end

function C = corrMatrix(X)
% Matriz de correlacao de Pearson entre as colunas de X (colunas constantes -> 0).
n = size(X, 1);
sd = std(X, 1);
sd(sd == 0) = Inf;
Z = bsxfun(@rdivide, bsxfun(@minus, X, mean(X)), sd);
C = (Z' * Z) / n;
C(1:size(C,1)+1:end) = 1;                 % diagonal = 1
end

function mi = mutualInfo(x, y, nb)
% Informacao mutua (em nats) entre duas variaveis, estimada com nb classes de igual
% frequencia em cada uma (apanha relacoes nao lineares que a correlacao nao ve).
if nargin < 3, nb = 10; end
n = numel(x);
bx = min(max(ceil(ranks(x) / n * nb), 1), nb);
by = min(max(ceil(ranks(y) / n * nb), 1), nb);
joint = accumarray([bx by], 1, [nb nb]) / n;
px = sum(joint, 2);  py = sum(joint, 1);
mi = 0;
for i = 1:nb
    for j = 1:nb
        if joint(i,j) > 0
            mi = mi + joint(i,j) * log(joint(i,j) / (px(i) * py(j)));
        end
    end
end
end

function r2 = r2score(y, yhat)
r2 = 1 - sum((y - yhat).^2) / sum((y - mean(y)).^2);
end

function s = joinStrings(c, sep)
% Junta uma cell de textos com um separador (a R2007a nao tem strjoin).
s = '';
for k = 1:numel(c)
    if k > 1, s = [s sep]; end
    s = [s c{k}];
end
end
