# 🌫️ Projeto de Previsão do Monóxido de Carbono (UCI Air Quality)

## 📌 Visão Geral

Este projeto prepara o dataset **UCI Air Quality** para a previsão horária da concentração de monóxido de carbono, **CO(GT)**, no âmbito da Unidade Curricular de Redes Neuronais Artificiais (Universidade da Madeira).

O problema é formulado como **regressão sobre uma série temporal**: a cada hora corresponde um valor real de CO e as medições dos sensores químicos e meteorológicos da estação. O trabalho foca-se na limpeza, análise, criação e seleção de features, deixando os dados prontos para as redes neuronais das fases seguintes.

---

## 🎯 Objetivos

- Limpar os dados sem quebrar a sequência temporal  
- Tratar as falhas de medição e os outliers usando apenas informação do treino  
- Criar novas features que acrescentem informação às originais  
- Selecionar um conjunto reduzido de features relevantes e não redundantes  
- Avaliar o resultado com um modelo linear de referência no conjunto de teste  

---

## 📊 Dataset

- Fonte: UCI Machine Learning Repository (Air Quality)  
- Ficheiro: `AirQualityUCI.csv` (9471 linhas, 17 colunas)  
- Medições horárias entre 10/03/2004 e 04/04/2005  
- O valor **-200** indica uma medição em falta  

### Variáveis

#### 🎯 Target
- CO(GT)

#### ⏱️ Temporais
- Date  
- Time  

#### 🧪 Sensores
- PT08.S1(CO)  
- PT08.S2(NMHC)  
- PT08.S3(NOx)  
- PT08.S4(NO2)  
- PT08.S5(O3)  

#### 🏭 Concentrações de referência
- NMHC(GT)  
- C6H6(GT)  
- NOx(GT)  
- NO2(GT)  

#### 🌡️ Meteorológicas
- T  
- RH  
- AH  

---

## ⚠️ Data Leakage

- Divisão **cronológica** 70% treino / 30% teste (sem baralhar)  
- Limites dos outliers, médias, desvios e receita da seleção calculados **só no treino** e aplicados ao teste  
- O target nunca é preenchido, normalizado nem sujeito a clipping  

---

## 🧹 Pré-processamento

- Remoção das colunas e linhas vazias do ficheiro  
- Conversão do código -200 para NaN  
- Remoção da variável NMHC(GT) (90.2% em falta)  
- Remoção das linhas sem target  
- Interpolação linear das falhas restantes  
- Clipping dos outliers com a regra 3×IQR  
- Normalização com StandardScaler  

---

## 🔍 Análise Exploratória (EDA)

- Estatísticas descritivas (média, desvio, assimetria, Pearson e Spearman)  
- Missing values por variável  
- Histogramas e boxplots  
- Relação das features com o target  
- Heatmap de correlação  
- Permutation importance  
- Redução de dimensionalidade:
  - PCA  
  - LDA  

---

## 🧠 Engenharia de Features

- Hora e dia da semana como ciclos (seno/cosseno)  
- Interações do sensor de CO com a temperatura e a humidade  

---

## ✂️ Seleção de Features

1. Remoção das irrelevantes (Pearson, Spearman e mutual information)  
2. Remoção das duplicadas  
3. Fusão de grupos colineares na 1.ª componente principal  
4. Remoção por permutation importance  

Resultado: **17 → 11 features**

---

## 🔄 Pipeline

1. Data Loader  
2. Data Cleaning  
3. Data Visualization  
4. Data Preprocessing  
5. EDA  
6. Feature Analysis (Feature Engineering e Feature Selection)  
7. Aplicação ao teste  
8. Verificação com um modelo linear  

---

## 🛠️ Tecnologias

- MATLAB R2007a (sem toolboxes)  
- LaTeX (relatório em formato IEEE)  

---

## 📂 Estrutura

```
projeto 1/
├── matlab/
│   ├── AirQualityUCI.csv
│   ├── nnlib.m
│   └── projeto.m
├── relatorio/
│   ├── relatorio.tex
│   └── figures/
└── README.md
```

- `nnlib.m` – biblioteca com as funções, organizada pelos mesmos módulos do pipeline  
- `projeto.m` – script que executa o pipeline completo, por ordem  

---

## 🚀 Como executar

- 1.º Abrir o MATLAB  
- 2.º Ir para o diretório **matlab** -> `cd 'projeto 1/matlab'`  
- 3.º Executar o projeto -> `projeto`  

Os resultados são escritos na consola e os gráficos abrem em janelas separadas.

---

## 📌 Insights

- A informação sobre o CO está concentrada nos sensores de poluição  
- A temperatura, a humidade relativa e a humidade absoluta não se relacionam diretamente com o CO  
- A hora do dia é a nova feature mais útil (dois picos de tráfego, às 8h e às 19h)  
- O efeito do sensor de CO depende da humidade  
- Modelo linear com as 11 features finais: **R² = 0.789** no teste  

---

## ⚠️ Desafios

- Muitas falhas de medição (código -200)  
- Variáveis muito redundantes  
- Série temporal (divisão cronológica e deriva dos sensores)  
- MATLAB R2007a sem toolboxes estatísticas  

---

## 👨‍💻 Autor

João Abreu

---
