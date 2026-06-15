# 🔧 Guia de Configuração - Gestão de Frota

## 🚨 ERRO: "infinite recursion detected in policy for relation "profiles""

Se receber este erro ao fazer login:

```
Erro ao obter perfil: infinite recursion detected in policy for relation "profiles"
```

**Solução rápida:**

1. Vá para [Supabase Dashboard](https://supabase.com) → Seu Projeto → **SQL Editor**
2. Execute o script **`database-simple-setup.sql`** (novo script SEM recursão)
3. Copie TODO o conteúdo e execute no editor SQL
4. ✅ Problema resolvido!

---

## ⚠️ SE RECEBEU OUTROS ERROS SQL ("relation does not exist")

Se recebeu erros como:
- "relation 'public.drivers' does not exist"
- "column shift_date does not exist"
- "relation 'public.shifts' does not exist"

### Solução Rápida:

1. Vá para [Supabase Dashboard](https://supabase.com) → Seu Projeto
2. Clique em **SQL Editor** → **New Query**
3. Abra o arquivo **`database-simple-setup.sql`** (recomendado - sem recursão RLS)
4. **Copie TODO o conteúdo** e cole no editor SQL
5. Clique em **"Run"**
6. ✅ Banco de dados recriado completamente!

---

## Problema: Login não funciona

O problema é que a tabela `profiles` não existe ou não tem o perfil do admin criado.

## Solução Normal (Primeira Vez)

### 1️⃣ Executar o Script SQL de Inicialização

**Use `database-simple-setup.sql` (recomendado - sem problemas de recursão RLS)**

1. Vá para [Supabase Dashboard](https://supabase.com)
2. Selecione seu projeto "gestão de frota"
3. Clique em **SQL Editor** → **New Query**
4. Abra `database-simple-setup.sql`
5. Copie **TODO** o conteúdo
6. Cole no editor SQL
7. Clique em **"Run"** para executar

### 2️⃣ Criar o Utilizador Admin

#### Opção A: Criar via Supabase Dashboard (Recomendado)

1. No Supabase, vá para **Authentication** → **Users**
2. Clique em **"Add user"**
3. Preencha com:
   - **Email**: admin@example.com (ou o email que preferir)
   - **Password**: Uma senha forte (ex: Admin123!@#)
4. Clique em **"Create user"**

#### Opção B: Criar via Supabase CLI

```bash
supabase auth create --email admin@example.com --password Admin123!@#
```

### 3️⃣ Definir o Admin como Administrador

1. No Supabase, vá para **SQL Editor**
2. Crie uma nova query
3. Execute este comando SQL:

```sql
UPDATE public.profiles SET role = 'admin', username = 'admin' WHERE email = 'admin@example.com';
```

⚠️ **Substitua `admin@example.com` pelo email que usou!**

### 4️⃣ Verificar se Funcionou

1. Abra a aplicação
2. Clique em **"Entrar"** ou aceda a `/login.html`
3. Digite o email e password que criou
4. Clique em **"Entrar"**

Se funcionar, será redirecionado para `/admin.html` ✅

### 5️⃣ Abrir a Consola do Browser para Ver Erros

Se ainda não funcionar:

1. Abra a aplicação e clique em **F12** (ou **Ctrl+Shift+I** / **Cmd+Option+I**)
2. Vá para a aba **"Console"**
3. Tente fazer login
4. Procure por mensagens de erro vermelhas
5. Copie a mensagem de erro

## Estrutura do Banco de Dados Criada

- **profiles**: Armazena os perfis dos utilizadores (admin ou driver)
- **vehicles**: Lista de veículos da frota
- **drivers**: Dados dos colaboradores
- **shifts**: Horários de trabalho
- **shift_reports**: Relatórios de turnos

## Problemas Comuns e Soluções

### ❌ "relation 'public.drivers' does not exist"
- As tabelas não foram criadas corretamente
- **Solução**: Use `database-final-setup.sql` (mais robusto)

### ❌ "column 'shift_date' does not exist"
- As tabelas não foram criadas com as colunas corretas
- **Solução**: Use `database-final-setup.sql`

### ❌ "Perfil não encontrado" no login
- O perfil do admin não foi criado
- **Solução**: Siga o passo 3 acima (UPDATE profiles SET role = 'admin'...)

### ❌ "Erro ao obter perfil"
- A tabela `profiles` não existe ou há erro de permissões
- **Solução**: Execute `database-final-setup.sql` novamente

### ❌ "Email não encontrado"
- O utilizador não foi criado no Supabase
- **Solução**: Crie o utilizador em **Authentication** → **Users**

### ❌ Login bem-sucedido mas página fica branca
- Há um erro na função `redirectBasedOnRole()`
- **Solução**: Abra F12 e veja o Console para mais detalhes

## Scripts Disponíveis

| Script | Quando Usar |
|--------|-------------|
| `database-setup.sql` | Primeiro setup (pode ter problemas) |
| `database-cleanup-and-setup.sql` | Se o primeiro falhou (intermediário) |
| `database-final-setup.sql` | Setup completo (pode ter recursão RLS) |
| `database-simple-setup.sql` | **🚀 RECOMENDADO** - Sem problemas de recursão RLS |

---

## ⚡ Resumo Rápido

1. **Execute `database-simple-setup.sql`** no Supabase SQL Editor
2. **Crie admin** em Authentication → Users
3. **Atualize role** com: `UPDATE public.profiles SET role = 'admin' WHERE email = 'admin@example.com';`
4. **Teste login** em https://frota-app-one.vercel.app/index.html

✅ Pronto!
