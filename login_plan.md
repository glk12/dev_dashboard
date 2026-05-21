# Login Plan

## Objetivo

Permitir que qualquer usuário faça login no sistema com a própria conta GitHub e use o app com um token próprio, em vez do token global atual em `credentials`.

O resultado desejado é:

- autenticação via GitHub
- associação de cada sessão a um usuário local
- armazenamento seguro de um fine-grained personal access token (FGPAT) por usuário
- uso do token do usuário nas chamadas para GitHub
- isolamento entre usuários
- fluxo claro para expiração, revogação e troca de token

## Estado atual do projeto

Hoje o projeto:

- não tem autenticação
- não tem tabela `users`
- não tem sessão por usuário
- usa um token global em `Rails.application.credentials.dig(:github, :access_token)`
- usa um username global em `Rails.application.credentials.dig(:github, :username)`
- filtra PRs pelo autor com esse username global

Arquivos relevantes:

- [app/services/github/client.rb](/home/glopes-a/dev_dashboard/app/services/github/client.rb:1)
- [app/services/github/pull_requests_fetcher.rb](/home/glopes-a/dev_dashboard/app/services/github/pull_requests_fetcher.rb:1)
- [app/controllers/my_pull_requests_controller.rb](/home/glopes-a/dev_dashboard/app/controllers/my_pull_requests_controller.rb:1)
- [db/schema.rb](/home/glopes-a/dev_dashboard/db/schema.rb:1)

## Decisão arquitetural recomendada

### Separar autenticação de autorização no GitHub

Você está falando em duas coisas diferentes:

1. Login com GitHub
2. Acesso à API do GitHub para ler PRs usando fine-grained token

Essas coisas não são a mesma credencial.

O login com GitHub deve ser feito com OAuth App ou GitHub App user authorization flow.

O fine-grained personal access token:

- é criado manualmente pelo usuário dentro do GitHub
- não é emitido pelo fluxo padrão de login OAuth
- precisa ser colado/registrado no seu sistema pelo próprio usuário

Conclusão importante:

- o usuário pode "entrar com GitHub"
- mas o FGPAT precisará ser conectado separadamente, a menos que você abandone FGPAT e use OAuth token/GitHub App token como credencial principal de API

## O que você precisa saber antes de implementar

### Limitação central do fine-grained token

Fine-grained PAT:

- é manual
- é vinculado à conta do usuário
- é limitado a repositórios específicos
- tem permissões específicas
- pode expirar
- pode ser revogado sem aviso prévio

Isso muda a UX:

- login bem-sucedido não significa acesso à API pronto
- o usuário pode estar logado mas sem token configurado
- o token pode estar configurado mas sem acesso aos repositórios cadastrados
- o token pode ter acesso parcial a alguns repositórios e não a outros

### Você precisa escolher o modelo de produto

Há 3 modelos possíveis:

1. Login com GitHub + usuário cola um fine-grained token
2. Login com GitHub + usar OAuth token para API e não usar FGPAT
3. GitHub App + login + instalação por usuário/organização

Para o que você pediu, o plano recomendado é o modelo 1.

Motivo:

- atende literalmente ao requisito de “logar com GitHub” e usar fine-grained token
- é simples de explicar
- é viável no stack atual
- evita reescrever o app inteiro para GitHub App agora

## Solução recomendada

### Fluxo final recomendado

1. Usuário entra clicando em `Sign in with GitHub`
2. App faz OAuth com GitHub e cria/atualiza um `User`
3. Usuário cai numa tela de onboarding
4. Se ele ainda não tiver um fine-grained token salvo, o app pede:
   - token
   - opcionalmente uma confirmação visual dos repositórios esperados
5. App valida o token contra a API do GitHub
6. Se válido, token é salvo criptografado
7. Todas as chamadas do dashboard passam a usar:
   - `current_user.github_username`
   - `current_user.github_token`
8. Se o token expirar ou perder permissão, o app pede reconexão

## Entidades que você vai precisar

### User

Campos recomendados:

- `github_uid`
- `github_login`
- `github_name`
- `github_email`
- `github_avatar_url`
- `github_profile_url`
- `oauth_provider`
- `last_signed_in_at`
- `created_at`
- `updated_at`

Restrições:

- `github_uid` unique
- `github_login` indexed

Observação:

- `github_email` pode vir vazio dependendo da configuração do usuário no GitHub
- não use email como chave principal de identidade
- use `github_uid`

### UserGithubCredential

Recomendado separar o token da tabela `users`.

Campos recomendados:

- `user_id`
- `encrypted_fine_grained_token`
- `token_last_four`
- `token_scopes_snapshot` ou `token_permissions_snapshot` em JSON
- `token_repository_access_snapshot` em JSON
- `token_expires_at`
- `last_validated_at`
- `last_validation_error`
- `active`
- `created_at`
- `updated_at`

Motivo da separação:

- reduz acoplamento
- facilita rotação de token
- deixa claro que login e token são responsabilidades distintas
- prepara o sistema para mais de uma credencial no futuro

### Session

Você pode usar a sessão padrão de Rails com cookie assinado, mas a solução mais robusta é ter tabela de sessões.

Opções:

1. sessão só em cookie Rails
2. tabela `sessions`

Recomendação:

- comece com sessão padrão Rails se quiser simplicidade
- adote tabela `sessions` se quiser revogação explícita, auditoria e múltiplos dispositivos

## Estratégia de autenticação

### Login com GitHub

Opção recomendada:

- `omniauth-github`

Fluxo:

1. usuário acessa `/auth/github`
2. GitHub redireciona para consentimento
3. callback chega em algo como `/auth/github/callback`
4. app lê:
   - `uid`
   - `info.nickname`
   - `info.name`
   - `info.email`
   - `info.image`
5. app faz `find_or_create_by!(github_uid: uid)`
6. app cria sessão

### Permissões do login OAuth

Para login puro, peça o mínimo necessário.

Na maioria dos casos:

- sem scopes extras, ou
- `read:user`
- `user:email` apenas se realmente precisar do email

Não confunda isso com permissões do fine-grained token.

## Estratégia para o fine-grained token

### Como o usuário vai fornecer o token

Fluxo recomendado:

1. após login, mostrar tela `Connect your GitHub token`
2. explicar por que o token é necessário
3. mostrar link direto para criar fine-grained token no GitHub
4. instruir o usuário sobre:
   - quais repositórios selecionar
   - quais permissões marcar
   - data de expiração recomendada
5. usuário cola o token
6. app valida
7. app armazena criptografado

### Permissões mínimas prováveis do token

Você precisa validar exatamente com a API que seu app usa, mas pelo comportamento atual, o app lê:

- pull requests abertas
- reviews de PR
- metadados de repositório

Então o token provavelmente precisará de permissões de leitura compatíveis com:

- Pull requests: read
- Contents / Metadata: read, se necessário para alguns endpoints
- Repository metadata: read

Você deve confirmar isso na documentação do GitHub durante a implementação.

Ponto crítico:

- permissões exatas de FGPAT são sensíveis ao endpoint
- valide endpoint por endpoint

### Validação do token

Quando o usuário salvar o token, o app deve:

1. instanciar cliente GitHub com esse token
2. chamar endpoint simples de verificação, por exemplo usuário autenticado
3. opcionalmente chamar um repositório conhecido
4. salvar snapshots de acesso/permissão quando possível

Se falhar, diferencie:

- token inválido
- token expirado
- token sem acesso ao repositório
- rate limit
- erro transitório do GitHub

## Segurança

### Como armazenar o token

Não armazene token em texto puro.

Recomendação em Rails 8:

- usar `Active Record Encryption`

Exemplo conceitual:

- `encrypts :fine_grained_token`

Alternativas:

- Lockbox
- KMS externo

Para este projeto, `Active Record Encryption` já é suficiente para começar.

### Regras de segurança mínimas

- nunca renderizar token de volta completo na UI
- mostrar só últimos 4 caracteres
- filtrar token em logs
- filtrar token em exceptions
- não salvar token em cookie ou session
- invalidar sessão no logout
- exigir HTTPS em produção
- proteger callback OAuth contra CSRF/state mismatch

### Risco operacional importante

Se você cadastrar repositórios globais no sistema, um usuário pode não ter acesso a todos eles com o próprio token.

Isso significa que o dashboard deve aceitar:

- sucesso parcial
- alguns repositórios visíveis
- alguns repositórios indisponíveis

Hoje o app já resgata erros por repositório em `PullRequestsFetcher`, o que ajuda.

## Mudanças de domínio necessárias

### Hoje o dashboard é global

Hoje:

- `Repository.active` é global
- `username` é global
- `access_token` é global

Quando entrar multiusuário, você precisa decidir:

1. repositórios continuam globais para todos
2. repositórios pertencem a cada usuário
3. modelo híbrido com repositórios compartilhados, mas visibilidade por usuário

Recomendação para começar:

- `repositories` continuam globais
- cada usuário só vê PRs do próprio `github_login`
- cada usuário usa o próprio token

Isso reduz mudança estrutural inicial.

### Quando repositórios globais podem falhar

Se `Repository.active` contiver repositórios:

- aos quais um usuário não tem acesso
- ou que não estão autorizados no token fine-grained dele

o app deve:

- ignorar esses repositórios no resultado
- mostrar aviso parcial opcional
- não quebrar a página inteira

## Mudanças de código necessárias

### 1. Adicionar autenticação base

Criar:

- `User` model
- controller/sessão para OAuth callback
- `current_user`
- `require_authentication`
- logout

Arquivos que provavelmente serão criados:

- `app/models/user.rb`
- `app/controllers/sessions_controller.rb`
- `app/controllers/concerns/authentication.rb` ou helper equivalente
- rotas de login/logout/callback

### 2. Adicionar credencial GitHub do usuário

Criar:

- `UserGithubCredential` model
- service para validar token
- form/UI para conectar ou atualizar token

Arquivos prováveis:

- `app/models/user_github_credential.rb`
- `app/services/github/token_validator.rb`
- `app/controllers/github_credentials_controller.rb`

### 3. Mudar o client GitHub para contexto por usuário

Hoje:

- `Github::Client` cai em token global

Mudança recomendada:

- `Github::Client` deve sempre receber credencial explícita em contexto autenticado
- evitar fallback silencioso para credentials globais

Recomendação:

- remover dependência de `default_access_token`
- usar token do usuário em todas as chamadas autenticadas

### 4. Mudar o fetcher para usar o usuário logado

Hoje `PullRequestsFetcher` aceita:

- `username`
- `access_token`

No futuro:

- receber `user:`
- ler `user.github_login`
- ler `user.github_credential`

Isso reduz ambiguidade e elimina configuração global.

### 5. Proteger páginas

Páginas que devem exigir login:

- dashboard de PRs
- repositories, se o produto for privado
- configuração do token

Páginas que podem ser públicas:

- landing page, se você quiser uma no futuro

### 6. Adicionar onboarding

Estados necessários:

- usuário não logado
- usuário logado sem token
- usuário logado com token inválido
- usuário logado com token válido

Sem esse onboarding, a UX vai parecer quebrada.

## Fluxos de tela necessários

### Fluxo 1: primeiro login

1. clicar em `Sign in with GitHub`
2. voltar autenticado
3. criar `User`
4. verificar se já existe `UserGithubCredential`
5. se não existe, redirecionar para `Connect token`

### Fluxo 2: conectar token

Tela deve explicar:

- por que o token é necessário
- quais repositórios incluir
- quais permissões marcar
- como copiar o token
- que ele será mostrado só uma vez no GitHub

Campos:

- token

Ações:

- salvar e validar
- cancelar/logout

### Fluxo 3: token inválido

Cenários:

- token malformado
- token revogado
- token expirado
- token sem acesso suficiente

Comportamento recomendado:

- bloquear dashboard com mensagem clara
- oferecer botão `Update token`

### Fluxo 4: dashboard com acesso parcial

Exemplo:

- usuário autenticado
- token válido
- acesso a 2 de 5 repositórios

Comportamento:

- mostrar PRs disponíveis
- exibir aviso discreto com lista dos repositórios inacessíveis

### Fluxo 5: logout

1. apagar sessão
2. redirecionar para landing/login

## Mudanças no banco

### Tabelas novas recomendadas

#### users

Campos:

- `github_uid`, string, null: false, unique
- `github_login`, string, null: false
- `github_name`, string
- `github_email`, string
- `github_avatar_url`, string
- `github_profile_url`, string
- `oauth_provider`, string, null: false, default: `github`
- `last_signed_in_at`, datetime

#### user_github_credentials

Campos:

- `user_id`, references, null: false
- `encrypted_fine_grained_token`, text, null: false
- `token_last_four`, string
- `token_permissions_snapshot`, jsonb, default: {}
- `token_repository_access_snapshot`, jsonb, default: {}
- `token_expires_at`, datetime
- `last_validated_at`, datetime
- `last_validation_error`, text
- `active`, boolean, default: true, null: false

### Possível mudança futura em repositories

Se você quiser repositórios por usuário:

- adicionar `user_id` em `repositories`

Mas eu não recomendo fazer isso na primeira etapa se o objetivo agora é só autenticar usuários e usar token próprio.

## Rotas novas recomendadas

Exemplo conceitual:

- `GET /login`
- `GET /auth/github`
- `GET /auth/github/callback`
- `DELETE /logout`
- `GET /settings/github-token`
- `PATCH /settings/github-token`

Opcional:

- `DELETE /settings/github-token`

## Configuração externa necessária

### No GitHub

Você vai precisar criar um GitHub OAuth App ou equivalente.

Dados necessários:

- Client ID
- Client Secret
- Homepage URL
- Callback URL

Exemplos de callback:

- desenvolvimento: `http://localhost:3000/auth/github/callback`
- produção: `https://seu-dominio.com/auth/github/callback`

### No Rails credentials ou ENV

Você vai precisar de:

- `GITHUB_OAUTH_CLIENT_ID`
- `GITHUB_OAUTH_CLIENT_SECRET`

Recomendação:

- usar variáveis de ambiente em produção
- não deixar isso hardcoded

## Bibliotecas recomendadas

### Para autenticação

Opção recomendada:

- `omniauth`
- `omniauth-github`

Alternativa:

- implementar OAuth manualmente com `oauth2`

Recomendação prática:

- use `omniauth-github`

### Para criptografia do token

Opção recomendada:

- Active Record Encryption nativo

### Para GitHub API

Você já usa:

- `octokit`

Pode continuar usando, mas ajuste a configuração e erros.

## Problemas que você vai encontrar

### 1. Usuário loga mas não tem token

Isso não é erro de login.

É um estado de onboarding incompleto.

### 2. Usuário tem token, mas não incluiu todos os repositórios

Esse é o caso mais comum com fine-grained token.

Você precisa aceitar isso como comportamento normal do produto.

### 3. Usuário muda username no GitHub

Se você usa `github_uid` como identidade, isso não quebra login.

Mas você deve atualizar `github_login` a cada autenticação.

### 4. Email pode faltar

Não use email como chave obrigatória.

### 5. Rate limit e falhas de API

Você já faz um rescue por repositório.

Precisa melhorar classificação do erro para:

- autenticação
- autorização
- rate limiting
- indisponibilidade temporária

### 6. Fine-grained token não é ideal para experiência totalmente automática

Se no futuro você quiser onboarding mais simples, o caminho mais limpo é GitHub App.

## Plano de execução recomendado

### Fase 1: fundação de autenticação

Implementar:

- `User`
- login/logout GitHub
- sessão
- `current_user`
- proteção de rotas

Critério de pronto:

- usuário consegue entrar e sair
- dashboard exige login

### Fase 2: credencial GitHub por usuário

Implementar:

- `UserGithubCredential`
- tela de conectar token
- criptografia
- validação do token

Critério de pronto:

- usuário consegue salvar token próprio
- token inválido é rejeitado com erro claro

### Fase 3: trocar chamadas globais por chamadas do usuário

Implementar:

- remover dependência de `credentials[:github][:access_token]`
- remover dependência de `credentials[:github][:username]`
- usar `current_user`

Critério de pronto:

- dashboard usa só token e login do usuário autenticado

### Fase 4: UX de estados e erros

Implementar:

- tela “connect token”
- estado “token expirado”
- aviso de acesso parcial a repositórios
- ações de reconectar token

Critério de pronto:

- usuário entende exatamente o que falta quando algo não funciona

### Fase 5: endurecimento de segurança

Implementar:

- filtros de logs
- testes de sessão
- testes de callback
- testes de criptografia e acesso

Critério de pronto:

- fluxo seguro em produção

## Testes que você precisa escrever

### Autenticação

- login cria usuário novo
- login reutiliza usuário existente
- logout limpa sessão
- rota protegida redireciona usuário anônimo

### Credencial

- salva token válido
- rejeita token inválido
- atualiza token existente
- não expõe token no HTML

### Dashboard

- usa `current_user.github_login`
- usa token do usuário atual
- ignora repositório sem acesso
- mostra erro amigável quando token está inválido

### Segurança

- token filtrado em logs/params
- usuário A não acessa credencial do usuário B

## Perguntas que você precisa responder antes de codar

### Produto

- repositórios serão globais ou por usuário?
- qualquer pessoa com GitHub pode entrar, ou só membros de uma org específica?
- o app é interno ou público?

### Segurança

- onde as chaves OAuth vão ficar em produção?
- qual política de expiração de sessão?
- você quer forçar revalidação do token periodicamente?

### UX

- quer onboarding em uma página simples ou wizard?
- quer permitir uso parcial do app sem token?
- quer mostrar lista dos repositórios autorizados pelo token?

## Recomendação final

Para este projeto, eu seguiria exatamente esta ordem:

1. login com GitHub usando OAuth
2. `User` local com sessão
3. tela de conectar fine-grained token
4. armazenamento criptografado do token
5. migrar `PullRequestsFetcher` e `Github::Client` para `current_user`
6. tratar acesso parcial e token expirado

## Resumo executivo

O principal ponto que você precisa ter claro é:

- login com GitHub não substitui o fine-grained token
- o fine-grained token será uma segunda etapa de conexão
- isso exige onboarding e tratamento de estados

A arquitetura mais segura e pragmática para o app atual é:

- autenticação por OAuth GitHub
- usuário local persistido
- token fine-grained por usuário, criptografado
- repositórios globais no início
- dashboard filtrado pelo usuário autenticado

Se depois você quiser a melhor experiência possível de autorização GitHub, o passo seguinte natural é migrar de fine-grained PAT para GitHub App.
