# 🆘 Guia de Resolução de Problemas - Recursão RLS

## 🔴 Erro: "infinite recursion detected in policy for relation "profiles""

Este erro ocorre quando uma política RLS tenta referenciar a própria tabela, causando um loop infinito.

### Por que acontece?

A política RLS antigo fazia isto:

```sql
CREATE POLICY "profiles_select_admin" ON public.profiles
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE ...)  -- ❌ RECURSÃO!
  );
```

Quando o Supabase tenta verificar a política, ele tenta:
1. Ler dados da tabela `profiles`
2. A política diz: "primeiro verifica se é admin consultando `profiles`"
3. Isto causa outra consulta a `profiles`
4. Que dispara a política novamente... **infinito!**

---

## ✅ SOLUÇÃO RÁPIDA (5 minutos)

### Passo 1: Limpar o Database Completamente

1. Abra [Supabase Dashboard](https://supabase.com) → Seu Projeto → **SQL Editor**
2. Clique em **"New Query"**
3. **Cole este script de limpeza:**
   - Abra o ficheiro `database-cleanup.sql` (novo ficheiro)
   - Copie TODO o conteúdo
   - Cole no editor SQL do Supabase
4. Clique em **"Run"**
5. ✅ Tudo foi eliminado (tabelas, triggers, políticas, etc.)

### Passo 2: Executar o Script Novo (SEM RECURSÃO)

1. Abra o ficheiro **`database-simple-setup.sql`** no seu editor
2. Copie **TODO** o conteúdo (está corrigido agora - profiles SEM RLS)
3. Volte ao **Supabase SQL Editor** → Clique em **"New Query"**
4. Cole o conteúdo completo
5. Clique em **"Run"**

✅ **Pronto!** O database foi recriado SEM erros de recursão.

### Passo 3: Recriar o Utilizador Admin

1. Vá para **Authentication** → **Users**
2. Clique em **"Add user"** (ou **"Create new user"**)
3. Preencha:
   - **Email**: admin@example.com (ou outro email)
   - **Password**: Uma password forte (ex: Admin@12345)
4. Clique em **"Create user"**

### Passo 4: Definir o Utilizador como Admin

1. Volte ao **SQL Editor** → **New Query**
2. Cole:

```sql
UPDATE public.profiles 
SET role = 'admin', username = 'admin' 
WHERE email = 'admin@example.com';
```

3. Clique em **Run**

✅ **Feito!** Agora o utilizador é admin.

### Passo 5: Testar o Login

1. Abra a aplicação: https://frota-app-one.vercel.app/
2. (Ou **Ctrl+F5** se já tinha aberta para limpar cache)
3. Abra **F12** → **Console** para ver se há erros
4. **Tente fazer login** com:
   - Email: `admin@example.com`
   - Password: a que definiu
5. Clique em **"Entrar"**

---

## 📋 Checklist de Resolução

- [ ] Script de limpeza executado com sucesso
- [ ] `database-simple-setup.sql` executado completamente
- [ ] Utilizador admin criado em Authentication
- [ ] UPDATE para role='admin' executado
- [ ] Cache do browser limpo (Ctrl+Shift+Delete)
- [ ] Página recarregada (Ctrl+F5)
- [ ] Console verificado (F12 → Console)
- [ ] Login testado

---

## 🔍 Se ainda não funcionar

### 1️⃣ Verificar se a tabela profiles existe

```sql
SELECT * FROM public.profiles LIMIT 1;
```

Se dieser erro, o script não executou corretamente. Tente novamente do Passo 1.

### 2️⃣ Verificar se o utilizador foi criado

```sql
SELECT user_id, email, role FROM public.profiles WHERE email = 'admin@example.com';
```

Se não aparecer nada, o UPDATE não funcionou ou o utilizador não foi criado.

### 3️⃣ Verificar o Console do Browser

1. Abra F12 → **Console**
2. Tente fazer login
3. Procure por mensagens vermelhas de erro
4. Copie a mensagem de erro completa
5. Procure a solução específica abaixo

---

## 🐛 Outros Erros Relacionados

### "PERMISSION DENIED for schema public"
**Causa**: Supabase Auth sem permissão de leitura
**Solução**: Desabilitar RLS em `profiles` completamente

```sql
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
```

### "Policy with check option violated"
**Causa**: Políticas RLS não permitem a operação
**Solução**: Simplificar as políticas (veja o `database-simple-setup.sql`)

### "Row level security violation"
**Causa**: O utilizador não tem permissão para aceder aos dados
**Solução**: Verificar que o perfil foi criado corretamente com `SELECT * FROM profiles WHERE user_id = auth.uid();`

---

## 💡 Notas Técnicas

O novo script `database-simple-setup.sql`:

✅ **Evita recursão** usando `auth.uid()` em vez de `EXISTS` com a mesma tabela
✅ **Mais rápido** porque as políticas são mais simples
✅ **Funciona melhor** com Supabase anon key
✅ **Mantém segurança** com verificações de role admin

A chave é: **Nunca faça uma subconsulta à tabela que está a proteger dentro da USING clause!**

---

## 📞 Precisa de mais ajuda?

1. Verificar todos os passos acima novamente
2. Procurar erros no Console do Browser (F12)
3. Confirmar que `database-simple-setup.sql` foi executado sem erros
4. Confirmar que o utilizador admin foi criado
5. Confirmar que o UPDATE foi executado

✅ Se tudo isto foi feito, o login deve funcionar!
