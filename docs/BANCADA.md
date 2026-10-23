# Bancada MT5 sintética

Esta pasta é a árvore que o coordenador transfere, sem alterações, para a raiz de `JulioCosta75/forge-mt5-capability`. Os caminhos do workflow são os da raiz desse repositório (`ea/ForgeSynthMA.mq5`), não os do orchestrator (`mt5-bancada/ea/...`).

O EA é um cruzamento de médias móveis simples com parâmetros fixos no código: período rápido 12, período lento 48, lote 0.01, magic 760003, desvio de 10 pontos, uma decisão por barra nova. Não há promessa de resultado. Não há inputs para otimizar.

## P1 — compilação

O job instala o MetaTrader 5 pelo instalador oficial, em modo automático, e corre `metaeditor64.exe /compile:<ea/ForgeSynthMA.mq5 copiado para MQL5\Experts> /log:<log> /include:<MQL5>`.

Prova, quando o job fica verde: o instalador passou a verificação descrita em «Instalador», o log de compilação tem `0 errors` e não tem uma contagem positiva de erros, e existe um `ForgeSynthMA.ex5` com tamanho maior que zero. O artefacto leva o log, o `.ex5`, `installer-signature.txt` e o sha256 de cada ficheiro produzido.

Não prova: que o cruzamento está certo, que há trades, que o resultado é lucrativo, nem que o `.ex5` corre numa conta. Um job vermelho por assinatura recusada não é um resultado de compilação.

## P2 — erro de compilação detetado

`ea/ForgeSynthMA_erro.mq5` é a cópia byte a byte de `ea/ForgeSynthMA.mq5` com um erro de sintaxe deliberado no fim (`int forge_p2_syntax_error = ;`).

O job passa só quando a falha é detetada: o código de saída de `metaeditor64.exe` é diferente de 0, ou o log (UTF-16 LE ou UTF-8) contém uma contagem de erros a partir de 1, ou uma linha com `: error`. Além disso, o job falha se ainda assim aparecer um `.ex5`. Um log apenas com `0 errors` não conta: essa frase também contém a palavra `error`, e corresponde a compilação aceite.

Não prova: a qualidade das mensagens do compilador, nem que qualquer outro erro seria apanhado. Um job vermelho por assinatura recusada não mostra que o erro de sintaxe foi detetado.

## P3 — Strategy Tester

P3 é um job separado. Sem os três segredos `MT5_DEMO_LOGIN`, `MT5_DEMO_PASSWORD` e `MT5_DEMO_SERVER`, escreve a linha `skipped: demo secrets ausentes` e termina com código 0. Nesse caso não instala o terminal e não falha P1 nem P2.

Com os três segredos, o job compila `ForgeSynthMA.mq5` e lança duas vezes:

`terminal64.exe /portable /config:<ini temporário>`

O ini tem `[Common]` com o login, a password e o servidor vindos só dos segredos, e `[Experts]` com `AllowLiveTrading=0`. `[Tester]` fica fixo:

| Chave | Valor |
| --- | --- |
| Expert | ForgeSynthMA |
| Symbol | EURUSD |
| Period | H1 |
| Model | 1 (1 minute OHLC) |
| ExecutionMode | 0 |
| Optimization | 0 |
| FromDate | 2024.01.02 |
| ToDate | 2024.02.02 |
| Deposit | 10000 |
| Currency | USD |
| Leverage | 1:100 |
| UseLocal | 1 |
| UseRemote | 0 |
| UseCloud | 0 |
| Visual | 0 |
| ShutdownTerminal | 1 |

Os dois relatórios são lidos como HTML. O job compara, como texto, `Total Net Profit`, `Total Trades` e o drawdown máximo (`Equity Drawdown Maximal`, ou `Balance Drawdown Maximal` se o primeiro não existir). Os dois runs têm de usar o mesmo rótulo e o mesmo valor.

Prova, quando o job fica verde com segredos: o instalador passou a verificação descrita em «Instalador» e, neste terminal, com este histórico descarregado na mesma sessão, os dois runs produziram os mesmos três campos. Os artefactos levam os relatórios redatados, o JSON, `installer-signature.txt` e os sha256. O ini temporário é apagado e não entra no artefacto.

Não prova: conta real, ordens fora do tester, o mesmo resultado noutro corretor ou noutra máquina, estabilidade do histórico ao longo do tempo, nem qualquer mérito económico do EA. `UseCloud=0` e `UseRemote=0` deixam de fora a rede paga de agentes. Também não prova que os relatórios omitidos do log estão livres de segredos: essa redacção é feita no passo do tester, com `Hide`, antes do upload. `Hide` não substitui valores com menos de 3 caracteres.

Cada job instala o terminal à parte. A instalação espera no máximo 15 minutos pelos executáveis. Cada um dos dois runs do tester espera no máximo 20 minutos pelo relatório. Se o histórico demo não chegar nesse prazo, P3 falha; P1 e P2 não dependem desse prazo.

## Instalador

A página oficial `https://www.metatrader5.com/en/download`, consultada em 2026-10-23, aponta para `https://download.terminal.free/cdn/web/metaquotes.ltd/mt5/mt5setup.exe`. O workflow descarrega esse URL. Antes de executar `mt5setup.exe`, grava `installer-signature.txt` e imprime no log estas linhas:

- `sha256` dos bytes descarregados
- `status` devolvido por `Get-AuthenticodeSignature`
- `subject` de `SignerCertificate`, vazio se não houver certificado
- `thumbprint` desse certificado, vazio se não houver
- `url` efetivo depois de redireções, quando o cliente HTTP o expõe; se não o expuser, o URL pedido

`installer.sha256` mantém a linha de hash. O executável não entra no artefacto.

O job só arranca o instalador se as três condições se verificarem ao mesmo tempo: o ficheiro começa por `MZ`, `status` é `Valid`, e `subject` contém a sequência `MetaQuotes` (comparação ordinal, sensível a maiúsculas). Se a assinatura falhar, o job termina sem executar `mt5setup.exe`. O cabeçalho `MZ` continua a ser exigido e não chega como prova de origem.

Quando a assinatura é aceite, a instalação usa `/auto /path:C:\mt5-bancada`, a forma automática documentada em `https://www.metatrader5.com/en/terminal/help/start_advanced/installation`. Não há outro instalador, mirror nem pacote de terceiros. Em P3 sem os três segredos, o instalador não é descarregado: não há verificação de assinatura nesse ramo, e `installer-signature.txt` fica ausente.

O modo `/portable` está documentado em `https://www.metatrader5.com/en/terminal/help/start_advanced/start` e fixa os dados no diretório de instalação, para o relatório ficar em `reports\`.

### O que a verificação Authenticode prova

No runner Windows desse job, nesse momento, `Get-AuthenticodeSignature` devolveu `Valid` para o `mt5setup.exe` descarregado e o subject do certificado continha `MetaQuotes`. `Valid` quer dizer que a assinatura confere com o hash do ficheiro e que a decisão de confiança desse Windows aceitou a cadeia, com o repositório de certificados e as regras de revogação dessa máquina.

### O que a verificação Authenticode não prova

- Não fixa o thumbprint. Outro certificado cujo subject contenha `MetaQuotes` passaria. O thumbprint fica gravado para comparação humana; o job não o exige.
- Não confirma que o URL é o da MetaQuotes. O URL efetivo é registado, não comparado com uma lista.
- Não verifica `metaeditor64.exe`, `terminal64.exe` nem os ficheiros extraídos. Só `mt5setup.exe`, e só antes de ser iniciado.
- Não se transporta para outro runner. Um repositório de certificados diferente, uma falha de revogação ou um certificado expirado mudam o `status`. O workflow não instala raízes nem desliga a revogação.
- Não prova o EA, a compilação nem o Strategy Tester.
- O cabeçalho `MZ` só indica que o ficheiro parece um PE. Não identifica o editor.

## Evidência no log

Cada job tem um passo final `Evidencia no log` com `if: always()`, portanto também corre quando o passo anterior falha. Imprime `installer-signature.txt` (ou `ausente`), `resultado.txt` e o `MANIFEST.sha256` do diretório de artefactos.

Em P1 e P2 imprime ainda as linhas do log de compilação que contenham `error`, `warning` ou `result`, sem distinção de maiúsculas, no máximo 50. Se houver mais, o log indica o corte. Não imprime o resto do log.

Em P3 esse passo não imprime o log de compilação nem os relatórios. Volta a aplicar `::add-mask::` e `Hide` ao texto que imprime. Sem segredos, `resultado.txt` contém `skipped: demo secrets ausentes` e `installer-signature.txt` está ausente.

Isto mostra o desfecho a quem lê o log do Actions. Não torna descarregável um artefacto que o verificador não consiga abrir. Se o job for cancelado por tempo limite antes deste passo, o log pode ficar sem este bloco.

## Permissões do token

O workflow pede apenas `permissions: contents: read` para P1, P2 e P3. Não pede `actions: write`.

## Segredos

Os três valores existem só como GitHub Secrets, criados pelo Fundador. Não há credenciais nestes ficheiros. O workflow não escreve os valores em claro. Em P3, cada passo que os recebe regista `::add-mask::` e passa o texto impresso ou gravado por `Hide`, que substitui cada valor de pelo menos 3 caracteres por `[redacted]`. Antes do upload, login, password e servidor são substituídos nos ficheiros de texto do artefacto. O passo de evidência de P3 não imprime o log de compilação nem os relatórios.

## Fora desta bancada

Conta real, repositório `JulioCosta75/Mt5`, material privado, ordens com o terminal ligado a mercado, agentes remotos ou cloud, e qualquer passo que exija pagamento. O repositório de bancada é público. Se um passo passar a exigir pagamento, a execução deve parar e o valor concreto fica registado na issue, sem ser pago daqui.

## O que ainda não foi executado

O ambiente que escreveu a correção do despacho 4 não tem Windows nem MetaTrader 5. `Get-AuthenticodeSignature` não foi executado aqui. P1, P2 e P3 não foram corridos sobre este YAML. O run `39955626939` é anterior a esta correção e não a valida.

A prova fica para o Actions do repositório de bancada, depois da transferência sem alterações e da conferência dos SHA-256. Enquanto o workflow está em `mt5-bancada/.github/workflows/` no orchestrator, o GitHub não o executa: só lê workflows em `.github/workflows/` na raiz. O registo dessa limitação está em `docs/planning/f6/entrega/ENTREGA.md` no `forge-orchestrator`; esse ficheiro não faz parte da árvore transferida.
