clear; clc; close all;
L = nnlib();

%% 1. Data Loader
% carregar o dataset
[header_global, data_global, isNum_global] = L.readCSV('AirQualityUCI.csv');
[nObs, nCols] = size(data_global);
fprintf('Observacoes Totais: %d | Variaveis Iniciais: %d\n\n', nObs, nCols);

% colunas e linhas vazias do ficheiro (antes da divisao, para nao mudarem o ponto de corte)
[header_global, data_global, isNum_global] = L.dropColumns(header_global, data_global, isNum_global);
[data_global, nEmptyRows] = L.dropEmptyRows(data_global, isNum_global);
fprintf('Linhas vazias removidas: %d | Observacoes reais: %d | Variaveis: %d\n', nEmptyRows, size(data_global,1), size(data_global,2));

% isolar a variavel target
target = 'CO(GT)';
if ~any(strcmp(header_global, target)), error(['Target nao encontrado: ' target]); end
fprintf('Target: %s\n', target);

% dividir o dataset: 70% treino e 30% teste
fprintf('\n A dividir os dados (70%% Treino / 30%% Teste, ordem cronologica)...\n');
[data_train, data_test] = L.splitDataset(data_global, 0.70, false);
fprintf('Dados Treino: %d linhas | Dados Teste: %d linhas\n', size(data_train,1), size(data_test,1));

header_tr = header_global;  isNum_tr = isNum_global;
header_te = header_global;  isNum_te = isNum_global;

%% 2. Data Cleaning
fprintf('\n--- A PROCESSAR O CONJUNTO DE TREINO ---\n');

% copia antes da limpeza, para o grafico antes e depois (Data Visualization)
header_raw = header_tr;  
isNum_raw = isNum_tr;  
data_raw = data_train;     

[data_train, nDup]                  = L.removeDuplicates(data_train);
[data_train, nCodes]                = L.replaceMissingCode(data_train, isNum_tr, -200);
[header_tr, data_train, isNum_tr]   = L.dropColumns(header_tr, data_train, isNum_tr, 'NMHC(GT)');
[data_train, nNoTarget]             = L.dropMissingTarget(header_tr, data_train, target);
[data_train, nMissing]              = L.handleMissingValues(data_train, isNum_tr);   % interpolacao linear
% fazer clip dos outliers
[data_train, nOut, lim_lower, lim_upper] = L.removeOutliers(data_train, isNum_tr, 3, header_tr, target);

fprintf('Duplicadas: %d | Codigos -200: %d | Linhas sem %s: %d | Outliers limitados: %d\n', nDup, nCodes, target, nNoTarget, nOut);
fprintf('Valores preenchidos por interpolacao: %d\n', sum(nMissing));
fprintf('Treino depois da limpeza: %d observacoes x %d variaveis\n', size(data_train,1), size(data_train,2));

%% 3. Data Visualization

% % de valores em falta por variavel (dataset completo, antes da divisao)
L.plotMissingValues(header_global, data_global, isNum_global, -200);

% antes e depois da limpeza
L.plotCleaningEffect(header_raw, data_raw, isNum_raw, header_tr, data_train, isNum_tr, {target, 'NOx(GT)', 'C6H6(GT)', 'PT08.S1(CO)'}, -200);

% busca as 11 variaveis originais
baseNames = header_tr(isNum_tr & ~strcmp(header_tr, target));    

% mostra distribuicoes
L.plotOriginalFeatures(header_tr, data_train, isNum_tr, target, baseNames);   
L.plotFeaturesVsTarget(header_tr, data_train, isNum_tr, target, 6);

%% 4. Data Preprocessing

% StandardScaler nas 11 variaveis
% Guarda-se uma copia em unidades reais para a EDA e para criar as features novas.
header_orig = header_tr; 
isNum_orig = isNum_tr;  
data_orig = data_train;

[data_train, params_norm] = L.normalizeFeatures(data_train, header_tr, isNum_tr, baseNames);

%% 5. EDA
T = L.summaryTable(header_orig, data_orig, isNum_orig, target);
fprintf('\nEstatisticas descritivas (Treino, unidades originais):\n');
L.printSummaryTable(T);

% PCA das 11 variaveis originais, com os pontos pintados pelos 3 grupos de CO
excluirPCA = setdiff(header_tr, baseNames);
L.pcaGroups(header_tr, data_train, isNum_tr, target, excluirPCA);

%% 6. Feature Analysis

% Seno/cosseno da hora e do dia da semana e interacoes do sensor 
[header_orig, data_orig, isNum_orig] = L.addTimeFeatures(header_orig, data_orig, isNum_orig, 'Date', 'Time');
header1 = header_orig;
[header_orig, data_orig, isNum_orig] = L.addInteractionFeatures(header_orig, data_orig, isNum_orig, {'PT08.S1(CO)', 'T', 'RH'});

timeNames  = {'Hour_sin', 'Hour_cos', 'DayOfWeek_sin', 'DayOfWeek_cos'};
interNames = header_orig(numel(header1)+1:end);                    % pela ordem em que foram criadas
newNames   = [timeNames interNames];

% Graficos das features novas 
L.plotFeatureEngineeringEffect(header_orig, data_orig, isNum_orig, target, baseNames, ...
             {timeNames, interNames}, {'+ hora e dia (seno/cosseno)', '+ sensor CO x temperatura/humidade'});
L.plotCyclicFeatures(header_orig, data_orig, isNum_orig, target);

L.plotEngineeredFeatures(header_orig, data_orig, isNum_orig, target, baseNames);

% Junta as features novas ao treino normalizado e normaliza-as
[header_tr, data_train, isNum_tr] = L.copyColumns(header_tr, data_train, isNum_tr, header_orig, data_orig, newNames);
[data_train, params_new] = L.normalizeFeatures(data_train, header_tr, isNum_tr, newNames);
dropList = {'Date', 'Time'};
[header_tr, data_train, isNum_tr] = L.dropColumns(header_tr, data_train, isNum_tr, dropList);

% Feature Selection
L.plotImportanceAll(header_tr, data_train, isNum_tr, target);

% cada ciclo (seno + cosseno)
ciclos = {{'Hour_sin', 'Hour_cos'}, {'DayOfWeek_sin', 'DayOfWeek_cos'}};

obrigatorias = {'DayOfWeek_sin', 'DayOfWeek_cos'};

[header_tr, data_train, isNum_tr, selection] = L.selectFeatures(header_tr, data_train, isNum_tr, target, 0.15, 0.1, 0.999, 0.9, ciclos, obrigatorias);
[header_tr, data_train, isNum_tr, removed] = L.removeUnimportantFeatures(header_tr, data_train, isNum_tr, target, 0.005, ciclos, obrigatorias);

% Matriz de correlacao das features escolhidas e do CO
L.plotCorrelationHeatmap(header_tr, data_train, isNum_tr, 'Matriz de correlacao das features escolhidas e do CO');

% LDA com as variaveis continuas escolhidas (sem as interacoes)
excluir = {};
for k = 1:numel(header_tr)
    if ~isempty(strfind(header_tr{k}, '_x_')), excluir{end+1} = header_tr{k}; end
end
L.ldaGroups(header_tr, data_train, isNum_tr, target, excluir);

%% 7. Teste 
fprintf('\n--- A PROCESSAR O CONJUNTO DE TESTE ---\n');

% Data Cleaning 
[data_test, nCodesT]                = L.replaceMissingCode(data_test, isNum_te, -200);
[header_te, data_test, isNum_te]    = L.dropColumns(header_te, data_test, isNum_te, 'NMHC(GT)');
[data_test, nNoTargetT]             = L.dropMissingTarget(header_te, data_test, target);
[data_test, nMissingT]              = L.handleMissingValues(data_test, isNum_te);
data_test = L.clipToLimits(data_test, isNum_te, lim_lower, lim_upper);       % limites do treino
fprintf('Teste | Codigos -200: %d | Linhas sem %s: %d\n', nCodesT, target, nNoTargetT);
fprintf('Teste | Valores preenchidos por interpolacao: %d\n', sum(nMissingT));

% Data Preprocessing (com a media e o desvio do treino)
header_te_orig = header_te;  isNum_te_orig = isNum_te;  data_te_orig = data_test;
data_test = L.normalizeFeatures(data_test, header_te, isNum_te, baseNames, params_norm);

% Feature Analysis: as mesmas features novas, normalizadas com os parametros do treino
[header_te_orig, data_te_orig, isNum_te_orig] = L.addTimeFeatures(header_te_orig, data_te_orig, isNum_te_orig, 'Date', 'Time');
[header_te_orig, data_te_orig, isNum_te_orig] = L.addInteractionFeatures(header_te_orig, data_te_orig, isNum_te_orig, {'PT08.S1(CO)', 'T', 'RH'});
[header_te, data_test, isNum_te] = L.copyColumns(header_te, data_test, isNum_te, header_te_orig, data_te_orig, newNames);
data_test = L.normalizeFeatures(data_test, header_te, isNum_te, newNames, params_new);
[header_te, data_test, isNum_te] = L.dropColumns(header_te, data_test, isNum_te, dropList);

% Selecao: repete o que o treino decidiu (colunas removidas e grupos juntados)
[header_te, data_test, isNum_te] = L.applySelection(header_te, data_test, isNum_te, selection);
if ~isempty(removed)
    [header_te, data_test, isNum_te] = L.dropColumns(header_te, data_test, isNum_te, removed);
end

% Validacao estrutural das ordens das colunas
if isequal(header_tr, header_te)
    fprintf('\nSUCESSO: a estrutura do conjunto de Treino e de Teste coincide!\n');
    fprintf(' -> Dados de Treino: %d observacoes, %d colunas\n', size(data_train,1), size(data_train,2));
    fprintf(' -> Dados de Teste:  %d observacoes, %d colunas\n', size(data_test,1), size(data_test,2));
else
    warning('ERRO: a estrutura final do Treino e do Teste difere. Verifica a selecao de features.');
end

%% 8. Verificacao: um modelo linear treinado no treino e avaliado no teste
idxF = find(isNum_tr & ~strcmp(header_tr, target));
Xtr = cell2mat(data_train(:, idxF));   ytr = cell2mat(data_train(:, strcmp(header_tr, target)));
Xte = cell2mat(data_test(:, idxF));    yte = cell2mat(data_test(:, strcmp(header_te, target)));
theta = [ones(size(Xtr,1), 1) Xtr] \ ytr;
pred = [ones(size(Xte,1), 1) Xte] * theta;
r2_test = 1 - sum((yte - pred).^2) / sum((yte - mean(yte)).^2);
fprintf('\nModelo linear com as %d features finais: R2 no teste = %.3f | RMSE = %.3f mg/m3\n', ...
        numel(idxF), r2_test, sqrt(mean((yte - pred).^2)));
fprintf('Features finais: %s\n', sprintf('%s | ', header_tr{idxF}));
