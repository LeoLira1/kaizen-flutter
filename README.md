# Kaizen Flutter

Aplicativo Flutter de acompanhamento de composição corporal a partir de
screenshots do Zepp Life. A extração é confirmada pelo usuário, armazenada no
Turso e transformada localmente em indicadores de evolução e recomposição.

## Kaizen Score

O Kaizen Score (0–100) é a média simples dos componentes que possuem dados
suficientes:

- consistência: dias distintos com medição nos últimos 14 dias, divididos por 14;
- ritmo: 100 dentro do intervalo configurado e redução proporcional fora dele;
- gordura: 100 quando a média melhora, 60 quando varia até 0,1 ponto percentual
  e 0 quando piora;
- músculo: 100 quando a média melhora, 60 quando varia até 0,1 kg e 0 quando
  piora;
- metas: média do progresso de peso e gordura desde a primeira medição.

As médias recentes usam duas janelas não sobrepostas de sete dias, ancoradas na
data da medição mais recente. Componentes sem dados suficientes não recebem
valores inventados e ficam fora da média.
