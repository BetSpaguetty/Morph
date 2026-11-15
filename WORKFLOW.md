# Fluxo Simples de Branches e Commits — Morph

Este guia foi feito para uma equipe de **3 programadores** (com foco em simplicidade e zero dor de cabeça com `rebase`).

---

## 1. Os 3 Tipos de Branches

| Branch | Para que serve | Quem mexe |
| :--- | :--- | :--- |
| **`main`** | **Principal / Estável.** Só tem o código testado e funcionando. | **Só recebe da `develop`** (gerenciada pelo líder técnico). |
| **`develop`** | **Integração.** Onde o trabalho dos 3 programadores se junta. | **Todos**, enviando suas branches para cá antes da `main`. |
| **`func/<nome>`**<br>**`correcao/<nome>`**<br>**`ajuste/<nome>`** | **Branches de trabalho** (em português):<br>• `func/`: nova funcionalidade (ex: `func/tela-inicial`)<br>• `correcao/`: consertar bug (ex: `correcao/borda-ipad`)<br>• `ajuste/`: visual, assets ou config (ex: `ajuste/cores`) | **Cada pessoa** trabalha na sua própria branch. |

> **Regra simples:** Ninguém programa direto na `main`. Cada um trabalha na sua branch (`func/`, `correcao/`, `ajuste/`), junta na `develop`, e quando a `develop` estiver pronta, ela vai para a `main`.

---

## 2. Onde, Quem e Quando fazer Commits

### Onde commitar
- **Sempre** na sua branch de trabalho (`func/...`, `correcao/...`, `ajuste/...`) dentro da pasta `Morph/`.
- **Nunca** direto na `main` (o sistema bloqueia automaticamente).

### Quem commita
- **Na branch de trabalho (`func/...`, `correcao/...`, `ajuste/...`):** o programador dono da tarefa.
- **Na `develop`:** qualquer um dos 3 programadores ao finalizar sua tarefa (fazendo merge da sua branch para a `develop`).
- **Na `main`:** apenas o programador responsável pela revisão/entrega final, trazendo tudo da `develop` para a `main` de forma direta.

### Quando commitar e subir (Passo a passo do dia a dia)

#### 1) Antes de começar uma tarefa nova:
Sempre crie sua branch saindo da `develop` atualizada:
```bash
git checkout develop
git pull origin develop
git checkout -b func/nome-da-sua-tarefa
```

#### 2) Enquanto estiver programando (na sua branch):
Sempre que terminar uma parte que compila, salve e suba para o GitHub:
```bash
git add .
git commit -m "descreva o que você fez"
git push
```
*(Você pode fazer isso quantas vezes quiser na sua branch sem atrapalhar os colegas!)*

#### 3) Quando terminar a tarefa (juntar na `develop`):
Você tem **2 jeitos simples** (escolha o que preferir):
- **Jeito A (1 comando no terminal):** estando na sua branch, rode:
  ```bash
  sh scripts/enviar-develop.sh
  ```
  Ele já faz o push da sua branch, atualiza a `develop`, junta sua branch na `develop` e sobe tudo para o GitHub.
- **Jeito B (pelo site do GitHub):** abra um Pull Request da sua branch (`func/...`) apontando para **`develop`** e clique em **Merge pull request** (direto, sem burocracia).

#### 4) Para atualizar sua branch com o que os colegas já subiram na `develop`:
```bash
git pull origin develop
```
*(Sem `rebase`, usando merge simples. Se houver conflito, resolva o arquivo no Xcode, salve e faça `git add . && git commit`.)*

#### 5) Subir da `develop` para a `main` (quando estiver tudo testado):
O líder técnico confere que a `develop` está compilando e envia direto para a `main` (via Pull Request `develop` → `main` no GitHub, com 1 clique em **Merge pull request**).

---

## 3. Dica de ouro para evitar conflitos no Xcode
- Criem **arquivos `.swift` separados** para cada tela ou componente novo (não mexam os 3 no `ContentView.swift` ao mesmo tempo).
- Nunca commitem alteração de `DEVELOPMENT_TEAM` no `project.pbxproj` (o hook já protege vocês disso).
