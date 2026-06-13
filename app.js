// Compressão de imagem e upload (inalterado)
function compressImage(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.readAsDataURL(file);
    reader.onload = (event) => {
      const img = new Image();
      img.src = event.target.result;
      img.onload = () => {
        const canvas = document.createElement('canvas');
        const maxWidth = 1200;
        let width = img.width;
        let height = img.height;
        if (width > maxWidth) {
          height = Math.round((height * maxWidth) / width);
          width = maxWidth;
        }
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, width, height);
        canvas.toBlob(
          (blob) => {
            if (!blob) {
              reject(new Error('Falha ao comprimir imagem'));
              return;
            }
            const fileName = `${Date.now()}_${file.name || 'foto.jpg'}`;
            resolve(new File([blob], fileName, { type: 'image/jpeg' }));
          },
          'image/jpeg',
          0.7
        );
      };
      img.onerror = reject;
    };
    reader.onerror = reject;
  });
}

async function uploadPhoto(file) {
  if (!file) return null;
  const compressed = await compressImage(file);
  const filePath = `uploads/${compressed.name}`;
  const { data, error } = await supabase.storage
    .from('fleet-photos')
    .upload(filePath, compressed, {
      cacheControl: '3600',
      upsert: false,
    });
  if (error) {
    console.error('Erro no upload:', error.message);
    alert('Erro ao enviar foto: ' + error.message);
    return null;
  }
  const { data: urlData } = supabase.storage
    .from('fleet-photos')
    .getPublicUrl(filePath);
  return urlData.publicUrl;
}

// Função para chamar a Edge Function (admin)
async function callEdgeFunction(action, payload, sessionToken) {
  const res = await fetch(EDGE_FUNCTION_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${sessionToken}`,
    },
    body: JSON.stringify({ action, ...payload }),
  });
  return res.json();
}

// Redirecionamento baseado no perfil (única definição)
async function redirectBasedOnRole(userId) {
  try {
    const { data: profile, error } = await supabase
      .from('profiles')
      .select('role')
      .eq('user_id', userId)
      .single();
    if (error || !profile) {
      console.error('Erro ao obter perfil:', error);
      await supabase.auth.signOut();
      window.location.href = 'index.html';
      return;
    }
    if (profile.role === 'admin') {
      window.location.href = 'admin.html';
    } else {
      window.location.href = 'driver.html';
    }
  } catch (e) {
    console.error(e);
    window.location.href = 'index.html';
  }
}

// Logout global
function setupLogout(buttonId) {
  document.getElementById(buttonId).addEventListener('click', async () => {
    await supabase.auth.signOut();
    window.location.href = 'index.html';
  });
}