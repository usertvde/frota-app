// Compressão de imagem
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

// Upload de foto
async function uploadPhoto(file) {
  if (!file) return null;
  try {
    const compressed = await compressImage(file);
    const filePath = `uploads/${compressed.name}`;
    const { data, error } = await window.supabase.storage
      .from('fleet-photos')
      .upload(filePath, compressed, {
        cacheControl: '3600',
        upsert: false,
      });
    if (error) throw error;
    const { data: urlData } = window.supabase.storage
      .from('fleet-photos')
      .getPublicUrl(filePath);
    return urlData.publicUrl;
  } catch (err) {
    console.error('Erro no upload:', err.message);
    alert('Erro ao enviar foto: ' + err.message);
    return null;
  }
}

// Chamar Edge Function
async function callEdgeFunction(action, payload, sessionToken) {
  const res = await fetch(window.EDGE_FUNCTION_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${sessionToken}`,
    },
    body: JSON.stringify({ action, ...payload }),
  });
  return res.json();
}

// Redirecionar com base no perfil
async function redirectBasedOnRole(userId) {
  try {
    const { data: profile, error } = await window.supabase
      .from('profiles')
      .select('role')
      .eq('user_id', userId)
      .maybeSingle();

    if (error) {
      console.error('Erro ao obter perfil:', error);
      await window.supabase.auth.signOut();
      window.location.href = 'index.html';
      return;
    }

    if (!profile) {
      console.error('Perfil não encontrado para user_id:', userId);
      await window.supabase.auth.signOut();
      alert('Perfil não encontrado. Contacta o administrador.');
      window.location.href = 'index.html';
      return;
    }

    if (profile.role === 'admin') {
      window.location.href = 'admin.html';
    } else if (profile.role === 'driver') {
      window.location.href = 'driver.html';
    } else {
      alert('Perfil desconhecido.');
      window.location.href = 'index.html';
    }
  } catch (err) {
    console.error('Erro no redirectBasedOnRole:', err);
    window.location.href = 'index.html';
  }
}

// Logout
function setupLogout(buttonId) {
  const btn = document.getElementById(buttonId);
  if (btn) {
    btn.addEventListener('click', async () => {
      await window.supabase.auth.signOut();
      window.location.href = 'index.html';
    });
  }
}