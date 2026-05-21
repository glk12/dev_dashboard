# Login Technical Plan

## Escopo fechado

Implementar exatamente este fluxo:

1. Login com GitHub OAuth
2. Criar `User` local
3. Depois do login, se não tiver token, redirecionar para `Connect GitHub Token`
4. Usuário cola o fine-grained token
5. App valida o token
6. Salva criptografado
7. Dashboard usa `current_user.github_login` + token salvo

## Decisões assumidas

- qualquer usuário com conta GitHub pode entrar
- autenticação será via GitHub OAuth
- credencial de API será um fine-grained personal access token colado manualmente
- `repositories` continuam globais nesta primeira versão
- cada usuário vê apenas os próprios PRs, filtrados por `current_user.github_login`
- cada usuário usa apenas o próprio token salvo

## Estado atual do app

Hoje o app:

- não tem autenticação
- não tem `users`
- não tem sessão de usuário
- usa token global em `Rails.application.credentials`
- usa username global em `Rails.application.credentials`
- lê PRs no dashboard com `Github::PullRequestsFetcher`

Pontos atuais que serão alterados:

- [app/controllers/application_controller.rb](/home/glopes-a/dev_dashboard/app/controllers/application_controller.rb:1)
- [app/controllers/my_pull_requests_controller.rb](/home/glopes-a/dev_dashboard/app/controllers/my_pull_requests_controller.rb:1)
- [app/services/github/client.rb](/home/glopes-a/dev_dashboard/app/services/github/client.rb:1)
- [app/services/github/pull_requests_fetcher.rb](/home/glopes-a/dev_dashboard/app/services/github/pull_requests_fetcher.rb:1)
- [config/routes.rb](/home/glopes-a/dev_dashboard/config/routes.rb:1)

## Implementação por fases

### Fase 1: modelo de dados

Objetivo:

- criar as entidades mínimas para autenticação e credencial GitHub por usuário

### 1.1 Criar tabela `users`

Criar migration para `users` com:

- `github_uid`, `string`, `null: false`
- `github_login`, `string`, `null: false`
- `github_name`, `string`
- `github_email`, `string`
- `github_avatar_url`, `string`
- `github_profile_url`, `string`
- `oauth_provider`, `string`, `null: false`, default: `"github"`
- `last_signed_in_at`, `datetime`
- timestamps

Índices:

- unique index em `github_uid`
- index em `github_login`

Modelo:

- `app/models/user.rb`

Validações recomendadas:

- presença de `github_uid`
- presença de `github_login`
- unicidade de `github_uid`

### 1.2 Criar tabela `user_github_credentials`

Criar migration para `user_github_credentials` com:

- `user_id`, reference, `null: false`, foreign key
- `encrypted_fine_grained_token`, `text`, `null: false`
- `token_last_four`, `string`
- `token_permissions_snapshot`, `jsonb`, `null: false`, default: `{}`
- `token_repository_access_snapshot`, `jsonb`, `null: false`, default: `{}`
- `token_expires_at`, `datetime`
- `last_validated_at`, `datetime`
- `last_validation_error`, `text`
- `active`, `boolean`, `null: false`, default: `true`
- timestamps

Índices:

- unique index em `user_id` se você quiser uma credencial ativa por usuário

Modelo:

- `app/models/user_github_credential.rb`

Associações:

- `User has_one :github_credential, class_name: "UserGithubCredential", dependent: :destroy`
- `UserGithubCredential belongs_to :user`

### 1.3 Criptografia

Usar `Active Record Encryption`.

No model `UserGithubCredential`:

- `encrypts :fine_grained_token`

Observação importante:

O nome de coluna recomendável para Active Record Encryption é o atributo lógico em vez do nome físico “encrypted_...”.

Portanto, em vez de:

- `encrypted_fine_grained_token`

é tecnicamente melhor usar:

- `fine_grained_token`

porque o Rails faz a criptografia no atributo.

Recomendação final:

- ajuste a migration para usar coluna `fine_grained_token`, `text`, `null: false`

e no model:

- `encrypts :fine_grained_token`

Essa abordagem é a mais limpa.

## Fase 2: autenticação com GitHub OAuth

Objetivo:

- permitir login e logout
- criar `User` local automaticamente
- manter `current_user` em sessão

### 2.1 Adicionar gems

Adicionar no `Gemfile`:

- `omniauth`
- `omniauth-github`

Opcional, se preferir simplificar integração com Rails:

- `omniauth-rails_csrf_protection`

### 2.2 Configurar OmniAuth

Criar initializer:

- `config/initializers/omniauth.rb`

Configuração esperada:

- provider `:github`
- `client_id` via ENV
- `client_secret` via ENV
- scopes mínimos:
  - `read:user`
  - `user:email` apenas se você quiser tentar email

Configurar `full_host` corretamente em produção se necessário.

### 2.3 Variáveis de ambiente

Definir:

- `GITHUB_OAUTH_CLIENT_ID`
- `GITHUB_OAUTH_CLIENT_SECRET`

Em desenvolvimento:

- `.env` se usar dotenv
- ou credentials locais

Em produção:

- variáveis de ambiente no deploy

### 2.4 Rotas de autenticação

Adicionar em [config/routes.rb](/home/glopes-a/dev_dashboard/config/routes.rb:1):

- `get "/login", to: "sessions#new"`
- `get "/auth/github/callback", to: "sessions#create"`
- `delete "/logout", to: "sessions#destroy"`

Opcional:

- `get "/auth/failure", to: "sessions#failure"`

### 2.5 SessionsController

Criar:

- `app/controllers/sessions_controller.rb`

Ações:

- `new`
  - renderiza tela com botão `Sign in with GitHub`
- `create`
  - lê `request.env["omniauth.auth"]`
  - faz upsert do usuário
  - grava sessão
  - se não tiver token, redireciona para `Connect GitHub Token`
  - se tiver token, redireciona para dashboard
- `destroy`
  - apaga sessão
  - redireciona para login
- `failure`
  - mostra erro amigável

### 2.6 Serviço de upsert do usuário OAuth

Criar:

- `app/services/github/oauth_user_upserter.rb`

Responsabilidade:

- receber payload do OmniAuth
- criar ou atualizar `User`

Campos atualizados a cada login:

- `github_login`
- `github_name`
- `github_email`
- `github_avatar_url`
- `github_profile_url`
- `last_signed_in_at`

Chave principal:

- `github_uid`

### 2.7 Sessão e `current_user`

Adicionar no [app/controllers/application_controller.rb](/home/glopes-a/dev_dashboard/app/controllers/application_controller.rb:1):

- método `current_user`
- método `authenticated?`
- método `require_authentication`
- helper_method para `current_user`

Sessão mínima:

- `session[:user_id] = user.id`

### 2.8 Proteger rotas

Exigir autenticação em:

- dashboard
- repositories
- tela de conectar token

Implementação:

- `before_action :require_authentication`

Recomendação:

- deixar `SessionsController#new`, `#create`, `#failure` públicos

## Fase 3: tela e fluxo de conexão do fine-grained token

Objetivo:

- captar o token do usuário
- validar antes de salvar
- salvar criptografado

### 3.1 Rotas de token

Adicionar:

- `get "/settings/github-token", to: "github_credentials#edit"`
- `patch "/settings/github-token", to: "github_credentials#update"`

Opcional:

- `delete "/settings/github-token", to: "github_credentials#destroy"`

### 3.2 Controller de credencial

Criar:

- `app/controllers/github_credentials_controller.rb`

Ações:

- `edit`
  - mostra estado atual
  - se não existir token, mostra onboarding
  - se existir, mostra último status e opção de trocar token
- `update`
  - recebe token
  - valida via service
  - salva/atualiza credencial
  - redireciona para dashboard em caso de sucesso
  - renderiza erro em caso de falha

### 3.3 Form object ou parâmetros fortes

Você pode manter simples com params fortes no controller:

- `params.require(:github_credential).permit(:fine_grained_token)`

Ou criar form object:

- `GithubCredentialForm`

Para esse app, params fortes bastam.

### 3.4 View de conexão do token

Criar:

- `app/views/github_credentials/edit.html.erb`

A tela deve explicar claramente:

- o login GitHub já foi concluído
- o token é necessário para consultar PRs
- o token deve ser fine-grained
- o token precisa incluir acesso aos repositórios desejados
- o token pode expirar

Elementos da tela:

- título
- explicação curta
- checklist de permissões mínimas
- campo password para token
- botão salvar
- link para GitHub criar token

Estados da tela:

- sem token configurado
- token configurado e válido
- token configurado mas com última validação falha

## Fase 4: validação do token

Objetivo:

- garantir que o token funciona antes de salvar

### 4.1 Criar service `Github::TokenValidator`

Criar:

- `app/services/github/token_validator.rb`

Entrada:

- `token`
- opcionalmente `expected_login`
- opcionalmente `repositories`

Saída recomendada:

- objeto simples com:
  - `success?`
  - `login`
  - `expires_at`
  - `permissions_snapshot`
  - `repository_access_snapshot`
  - `error_code`
  - `error_message`

### 4.2 O que validar na API

Validação mínima:

1. instanciar `Octokit::Client` com o token
2. chamar endpoint do usuário autenticado
3. confirmar que o login retornado bate com `current_user.github_login`

Isso é importante para evitar:

- usuário logado com uma conta
- colando token de outra conta

Recomendação:

- rejeitar token cujo `login` não corresponda ao `current_user.github_login`

### 4.3 Validação opcional por repositório

Opcional, mas recomendado:

- testar acesso de leitura a `Repository.active`

Isso permite detectar cedo:

- token válido, mas sem acesso aos repositórios do app

Essa validação não deve impedir salvar em todos os casos.

Melhor comportamento:

- token válido pode ser salvo
- snapshot registra quais repositórios têm acesso
- dashboard depois lida com acesso parcial

### 4.4 Tratamento de erros

Distinguir pelo menos:

- token inválido
- token de outra conta
- token expirado
- token sem acesso suficiente
- rate limit
- erro temporário GitHub

Isso precisa virar mensagem clara na UI.

## Fase 5: persistência da credencial

Objetivo:

- salvar o token com segurança e metadados úteis

### 5.1 Lógica de persistência

Criar ou atualizar `current_user.github_credential` com:

- `fine_grained_token`
- `token_last_four`
- `last_validated_at`
- `last_validation_error`
- `token_permissions_snapshot`
- `token_repository_access_snapshot`
- `token_expires_at`
- `active: true`

### 5.2 Nunca exibir o token completo

Na UI, mostrar apenas:

- `••••1234`

### 5.3 Filtro de logs

Adicionar em:

- `config/initializers/filter_parameter_logging.rb`

Garantir que os seguintes params sejam filtrados:

- `fine_grained_token`
- `token`

## Fase 6: trocar o dashboard para contexto do usuário atual

Objetivo:

- eliminar dependência de token e username globais

### 6.1 Alterar `Github::Client`

Arquivo:

- [app/services/github/client.rb](/home/glopes-a/dev_dashboard/app/services/github/client.rb:1)

Mudança:

- remover fallback para `default_access_token`
- exigir token explícito ao inicializar

Assinatura recomendada:

- `Github::Client.new(access_token:)`

Se token estiver ausente:

- levantar erro interno claro

Não manter fallback silencioso.

### 6.2 Alterar `Github::PullRequestsFetcher`

Arquivo:

- [app/services/github/pull_requests_fetcher.rb](/home/glopes-a/dev_dashboard/app/services/github/pull_requests_fetcher.rb:1)

Trocar assinatura atual por:

- `initialize(repositories:, user:)`

Internamente:

- `@username = user.github_login`
- `@client = Github::Client.new(access_token: user.github_credential.fine_grained_token)`

Remover:

- `default_username`
- fallback em `credentials`

### 6.3 Alterar controller do dashboard

Arquivo:

- [app/controllers/my_pull_requests_controller.rb](/home/glopes-a/dev_dashboard/app/controllers/my_pull_requests_controller.rb:1)

Nova lógica:

1. garantir autenticação
2. se `current_user` não tiver `github_credential`, redirecionar para `settings/github-token`
3. buscar PRs com:
   - `Github::PullRequestsFetcher.new(repositories: Repository.active, user: current_user).call`

### 6.4 Alterar outras áreas que usam GitHub

Qualquer uso futuro do client GitHub deve sempre ser por contexto do usuário autenticado.

Regra:

- nunca usar token global novamente

## Fase 7: fluxo de UX completo

Objetivo:

- deixar o sistema usável sem estados confusos

### 7.1 Tela de login

Criar:

- `app/views/sessions/new.html.erb`

Conteúdo:

- branding simples
- explicação do produto
- botão `Sign in with GitHub`

### 7.2 Redirecionamentos

Regras:

- usuário anônimo acessa dashboard -> vai para login
- usuário logado sem token -> vai para `Connect GitHub Token`
- usuário logado com token -> vai para dashboard

### 7.3 Navegação autenticada

Atualizar header para mostrar:

- `current_user.github_login`
- botão logout
- link de `GitHub Token`

### 7.4 Estado de token inválido

Se durante uso do dashboard o token falhar:

- capturar erro
- marcar `last_validation_error`
- redirecionar para tela de token com mensagem clara

### 7.5 Acesso parcial a repositórios

Como `repositories` são globais, um usuário pode não ter acesso a todos.

Melhoria recomendada:

- fazer o fetcher acumular erros por repositório
- retornar:
  - `pull_requests`
  - `inaccessible_repositories`

Não é obrigatório para a primeira entrega, mas é uma melhoria muito útil.

## Fase 8: testes

Objetivo:

- cobrir autenticação, segurança e uso do token do usuário

### 8.1 Model tests

Criar testes para:

- `User`
- `UserGithubCredential`

Cenários:

- usuário válido
- `github_uid` único
- associação `has_one`

### 8.2 Request/controller tests de sessão

Criar testes para:

- login via callback cria usuário
- login via callback atualiza usuário existente
- logout limpa sessão
- login failure redireciona corretamente

### 8.3 Tests do token validator

Criar testes para:

- token válido
- token inválido
- token de login diferente do usuário autenticado
- erro de permissão

Usar stubs do Octokit.

### 8.4 Tests do dashboard autenticado

Criar testes para:

- usuário sem login é redirecionado
- usuário logado sem token é redirecionado para connect token
- usuário logado com token usa `current_user.github_login`
- fetcher é chamado com o token do usuário

### 8.5 Tests de segurança

Criar testes para:

- token não aparece em resposta HTML
- params do token são filtrados
- usuário A não edita credencial de usuário B

## Ordem exata de implementação recomendada

### Etapa 1

Criar migrations e models:

- `User`
- `UserGithubCredential`

### Etapa 2

Adicionar gems e configurar OAuth GitHub.

### Etapa 3

Criar:

- `SessionsController`
- `OAuthUserUpserter`
- `current_user`
- `require_authentication`

### Etapa 4

Criar tela de login e rotas de login/logout.

### Etapa 5

Criar:

- `GithubCredentialsController`
- view `Connect GitHub Token`
- `Github::TokenValidator`

### Etapa 6

Persistir token criptografado e filtrar logs.

### Etapa 7

Migrar `Github::Client` e `Github::PullRequestsFetcher` para usar `current_user`.

### Etapa 8

Alterar dashboard para:

- exigir login
- redirecionar se não houver token
- usar token do usuário atual

### Etapa 9

Adicionar logout, link de settings e mensagens de erro/estado.

### Etapa 10

Escrever testes.

## Checklist técnico por arquivo

### Novos arquivos

- `app/models/user.rb`
- `app/models/user_github_credential.rb`
- `app/controllers/sessions_controller.rb`
- `app/controllers/github_credentials_controller.rb`
- `app/services/github/oauth_user_upserter.rb`
- `app/services/github/token_validator.rb`
- `app/views/sessions/new.html.erb`
- `app/views/github_credentials/edit.html.erb`
- `config/initializers/omniauth.rb`
- migrations de `users`
- migrations de `user_github_credentials`

### Arquivos a alterar

- [Gemfile](/home/glopes-a/dev_dashboard/Gemfile:1)
- [config/routes.rb](/home/glopes-a/dev_dashboard/config/routes.rb:1)
- [app/controllers/application_controller.rb](/home/glopes-a/dev_dashboard/app/controllers/application_controller.rb:1)
- [app/controllers/my_pull_requests_controller.rb](/home/glopes-a/dev_dashboard/app/controllers/my_pull_requests_controller.rb:1)
- [app/services/github/client.rb](/home/glopes-a/dev_dashboard/app/services/github/client.rb:1)
- [app/services/github/pull_requests_fetcher.rb](/home/glopes-a/dev_dashboard/app/services/github/pull_requests_fetcher.rb:1)
- [config/initializers/filter_parameter_logging.rb](/home/glopes-a/dev_dashboard/config/initializers/filter_parameter_logging.rb:1)
- [app/views/layouts/application.html.erb](/home/glopes-a/dev_dashboard/app/views/layouts/application.html.erb:1)

## Critérios de aceite

O trabalho estará correto quando:

1. usuário consegue entrar com GitHub
2. `User` local é criado ou atualizado
3. usuário sem token é redirecionado para `Connect GitHub Token`
4. usuário consegue colar token
5. token é validado contra GitHub
6. token é salvo criptografado
7. dashboard busca PRs usando:
   - `current_user.github_login`
   - token salvo do usuário
8. app não depende mais de:
   - `Rails.application.credentials.dig(:github, :access_token)`
   - `Rails.application.credentials.dig(:github, :username)`

## Riscos e cuidados

### 1. Token de uma conta diferente

Precisa ser rejeitado na validação.

### 2. Token válido, mas sem acesso aos repositórios

Não deve quebrar login.

Deve resultar em:

- dashboard parcial, ou
- aviso claro

### 3. GitHub email ausente

Não use email como identidade obrigatória.

### 4. Fine-grained token expira

A UI precisa suportar reconectar token.

### 5. Segurança de produção

Obrigatório em produção:

- HTTPS
- secrets em ENV
- logs filtrados
- cookies seguros

## Próxima divisão recomendada depois deste plano

Se você for implementar em sequência, o breakdown ideal é:

1. `auth foundation`
2. `github token onboarding`
3. `dashboard migration to current_user`
4. `tests and hardening`

Esse é o melhor corte de PRs também.
