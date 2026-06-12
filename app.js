// ------------------------------------
// Função de compressão de imagem
// Reduz a imagem para no máximo 1200px de largura e qualidade 0.7
// ------------------------------------
function compressImage(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.readAsDataURL(file);
    reader.onload = (event) => {
      const img = new Image();
      img.src = event.target.result;
      img.onload = () => {
        const canvas = document.createElement('canvas');
        const maxWidth = 1200; // pixels
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
            // Dá um nome único à imagem
            const fileName = `${Date.now()}_${file.name || 'foto.jpg'}`;
            resolve(new File([blob], fileName, { type: 'image/jpeg' }));
          },
          'image/jpeg',
          0.7 // qualidade
        );
      };
      img.onerror = reject;
    };
    reader.onerror = reject;
  });
}

// ------------------------------------
// Função para fazer upload de uma foto comprimida e devolver o URL público
// ------------------------------------
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

  // Obter URL público
  const { data: urlData } = supabase.storage
    .from('fleet-photos')
    .getPublicUrl(filePath);
  return urlData.publicUrl;
}

// ------------------------------------
// Verificar sessão e carregar dados
// ------------------------------------
let currentSession = null;

async function checkAuth() {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) {
    window.location.href = 'index.html';
    return null;
  }
  currentSession = session;
  return session;
}

// Logout
document.getElementById('logout-btn').addEventListener('click', async () => {
  await supabase.auth.signOut();
  window.location.href = 'index.html';
});

// ------------------------------------
// Gestão de separadores
// ------------------------------------
const tabs = document.querySelectorAll('.tab');
const panels = document.querySelectorAll('.panel');
tabs.forEach(tab => {
  tab.addEventListener('click', () => {
    tabs.forEach(t => t.classList.remove('active'));
    panels.forEach(p => p.classList.remove('active'));
    tab.classList.add('active');
    document.getElementById(`${tab.dataset.tab}-panel`).classList.add('active');
    // Recarregar listas quando se muda de separador
    if (tab.dataset.tab === 'vehicles') loadVehicles();
    if (tab.dataset.tab === 'drivers') loadDrivers();
    if (tab.dataset.tab === 'trips') {
      loadVehiclesForSelect();
      loadDriversForSelect();
      loadTrips();
    }
  });
});

// ------------------------------------
// CRUD Veículos
// ------------------------------------
async function loadVehicles() {
  const { data, error } = await supabase.from('vehicles').select('*').order('id', { ascending: false });
  if (error) return;
  const list = document.getElementById('vehicles-list');
  list.innerHTML = data.map(v => `
    <div class="card">
      ${v.photo_url ? `<img src="${v.photo_url}" alt="Foto" style="max-width:150px;">` : ''}
      <p><strong>${v.brand} ${v.model}</strong> (${v.year})</p>
      <p>Matrícula: ${v.license_plate}</p>
      <button onclick="deleteVehicle(${v.id})">Apagar</button>
    </div>
  `).join('');
}

document.getElementById('vehicle-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const brand = document.getElementById('v-brand').value;
  const model = document.getElementById('v-model').value;
  const plate = document.getElementById('v-plate').value;
  const year = document.getElementById('v-year').value;
  const photoFile = document.getElementById('v-photo').files[0];

  let photo_url = null;
  if (photoFile) {
    photo_url = await uploadPhoto(photoFile);
  }

  const { error } = await supabase.from('vehicles').insert({
    brand, model, license_plate: plate, year: parseInt(year) || null, photo_url
  });
  if (error) alert('Erro: ' + error.message);
  else {
    document.getElementById('vehicle-form').reset();
    loadVehicles();
  }
});

async function deleteVehicle(id) {
  if (!confirm('Apagar este veículo?')) return;
  await supabase.from('vehicles').delete().eq('id', id);
  loadVehicles();
}

// ------------------------------------
// CRUD Condutores
// ------------------------------------
async function loadDrivers() {
  const { data, error } = await supabase.from('drivers').select('*').order('id', { ascending: false });
  if (error) return;
  document.getElementById('drivers-list').innerHTML = data.map(d => `
    <div class="card">
      <p><strong>${d.name}</strong></p>
      <p>Email: ${d.email || '-'} | Tel: ${d.phone || '-'}</p>
      <button onclick="deleteDriver(${d.id})">Apagar</button>
    </div>
  `).join('');
}

document.getElementById('driver-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const name = document.getElementById('d-name').value;
  const email = document.getElementById('d-email').value;
  const phone = document.getElementById('d-phone').value;
  const { error } = await supabase.from('drivers').insert({ name, email, phone });
  if (error) alert('Erro: ' + error.message);
  else {
    document.getElementById('driver-form').reset();
    loadDrivers();
  }
});

async function deleteDriver(id) {
  if (!confirm('Apagar este condutor?')) return;
  await supabase.from('drivers').delete().eq('id', id);
  loadDrivers();
}

// ------------------------------------
// CRUD Utilizações
// ------------------------------------
async function loadVehiclesForSelect() {
  const { data } = await supabase.from('vehicles').select('id, brand, model');
  const select = document.getElementById('t-vehicle');
  select.innerHTML = '<option value="">Seleciona veículo</option>' +
    data.map(v => `<option value="${v.id}">${v.brand} ${v.model}</option>`).join('');
}

async function loadDriversForSelect() {
  const { data } = await supabase.from('drivers').select('id, name');
  const select = document.getElementById('t-driver');
  select.innerHTML = '<option value="">Seleciona condutor</option>' +
    data.map(d => `<option value="${d.id}">${d.name}</option>`).join('');
}

async function loadTrips() {
  const { data, error } = await supabase.from('trips')
    .select('*, vehicles(brand, model), drivers(name)')
    .order('id', { ascending: false });
  if (error) return;
  document.getElementById('trips-list').innerHTML = data.map(t => `
    <div class="card">
      <p><strong>${t.vehicles?.brand} ${t.vehicles?.model}</strong> conduzido por ${t.drivers?.name}</p>
      <p>Início: ${new Date(t.start_time).toLocaleString()} | Km: ${t.start_km}</p>
      ${t.end_time ? `<p>Fim: ${new Date(t.end_time).toLocaleString()} | Km: ${t.end_km}</p>` : '<p>Em andamento</p>'}
      ${t.start_photo_url ? `<img src="${t.start_photo_url}" width="100">` : ''}
      ${t.end_photo_url ? `<img src="${t.end_photo_url}" width="100">` : ''}
      <p>Notas: ${t.notes || '-'}</p>
      <button onclick="deleteTrip(${t.id})">Apagar</button>
    </div>
  `).join('');
}

document.getElementById('trip-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const vehicle_id = document.getElementById('t-vehicle').value;
  const driver_id = document.getElementById('t-driver').value;
  const start_time = document.getElementById('t-start-time').value
    ? new Date(document.getElementById('t-start-time').value).toISOString()
    : new Date().toISOString();
  const end_time = document.getElementById('t-end-time').value
    ? new Date(document.getElementById('t-end-time').value).toISOString()
    : null;
  const start_km = parseInt(document.getElementById('t-start-km').value);
  const end_km = document.getElementById('t-end-km').value ? parseInt(document.getElementById('t-end-km').value) : null;
  const start_photo = document.getElementById('t-start-photo').files[0];
  const end_photo = document.getElementById('t-end-photo').files[0];
  const notes = document.getElementById('t-notes').value;

  let start_photo_url = null;
  let end_photo_url = null;
  if (start_photo) start_photo_url = await uploadPhoto(start_photo);
  if (end_photo) end_photo_url = await uploadPhoto(end_photo);

  const { error } = await supabase.from('trips').insert({
    vehicle_id: parseInt(vehicle_id),
    driver_id: parseInt(driver_id),
    start_time,
    end_time,
    start_km,
    end_km,
    start_photo_url,
    end_photo_url,
    notes
  });
  if (error) alert('Erro: ' + error.message);
  else {
    document.getElementById('trip-form').reset();
    loadTrips();
  }
});

async function deleteTrip(id) {
  if (!confirm('Apagar esta utilização?')) return;
  await supabase.from('trips').delete().eq('id', id);
  loadTrips();
}

// ------------------------------------
// Inicialização
// ------------------------------------
(async () => {
  const session = await checkAuth();
  if (session) {
    // Carrega os dados do primeiro painel ativo
    loadVehicles();
    // Preenche os selects do separador de utilizações para quando for clicado
    loadVehiclesForSelect();
    loadDriversForSelect();
    loadTrips();
  }
})();