// Quando a página carrega, verifica se já há sessão
window.addEventListener('DOMContentLoaded', async () => {
  const { data: { session } } = await window.supabase.auth.getSession();
  if (session) {
    // Já está logado, vai direto para a app
    window.location.href = 'app.html';
  }
});

// Lidar com o formulário de envio do email
document.getElementById('login-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const email = document.getElementById('email').value;
  const { error } = await window.supabase.auth.signInWithOtp({
    email: email,
    options: {
      // O link mágico redireciona para callback.html
      emailRedirectTo: window.location.origin + '/callback.html',
    },
  });
  const msg = document.getElementById('message');
  if (error) {
    msg.textContent = 'Erro: ' + error.message;
  } else {
    msg.textContent = 'Link enviado! Verifica o teu email e clica no link recebido.';
  }
});