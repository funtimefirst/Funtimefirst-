/*
  Z-Tracker Survival App
  Major sections:
  1) App state + storage
  2) Form handlers (sightings, safe zones, supplies)
  3) Rendering + dashboard calculations
  4) Alerts, filters, geolocation, import/export
*/

const STORAGE_KEY = "ztracker_state_v1";
const THREAT_RANK = { Low: 1, Medium: 2, High: 3, Critical: 4 };

const defaultState = {
  daysSurvived: 1,
  sightings: [],
  safeZones: [],
  supplies: [
    { id: crypto.randomUUID(), category: "Food", quantity: 10, threshold: 5 },
    { id: crypto.randomUUID(), category: "Water", quantity: 10, threshold: 5 },
    { id: crypto.randomUUID(), category: "Ammo", quantity: 30, threshold: 10 },
    { id: crypto.randomUUID(), category: "Medical", quantity: 6, threshold: 3 },
  ],
};

let state = loadState();

const $ = (id) => document.getElementById(id);

const ui = {
  alertBanner: $("alertBanner"),
  totalSightings: $("totalSightings"),
  highestThreat: $("highestThreat"),
  daysSurvived: $("daysSurvived"),
  supplyHealth: $("supplyHealth"),
  sightingsList: $("sightingsList"),
  safeZonesList: $("safeZonesList"),
  supplyList: $("supplyList"),
  mapList: $("mapList"),
};

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return structuredClone(defaultState);
    const parsed = JSON.parse(raw);
    return {
      ...structuredClone(defaultState),
      ...parsed,
      sightings: parsed.sightings || [],
      safeZones: parsed.safeZones || [],
      supplies: parsed.supplies?.length ? parsed.supplies : structuredClone(defaultState.supplies),
    };
  } catch {
    return structuredClone(defaultState);
  }
}

function persist() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function isoDateOnly(isoString) {
  return new Date(isoString).toISOString().slice(0, 10);
}

function highestThreat() {
  if (!state.sightings.length) return "Low";
  return state.sightings.reduce((top, s) => (THREAT_RANK[s.threat] > THREAT_RANK[top] ? s.threat : top), "Low");
}

function supplyHealthSummary() {
  const low = state.supplies.filter((s) => s.quantity <= s.threshold);
  if (!low.length) return "Stable";
  if (low.length >= 2) return "Critical";
  return "Low";
}

function showAlert(message) {
  ui.alertBanner.textContent = message;
  ui.alertBanner.classList.remove("hidden");
  clearTimeout(showAlert._timer);
  showAlert._timer = setTimeout(() => ui.alertBanner.classList.add("hidden"), 5000);
}

function renderStats() {
  ui.totalSightings.textContent = String(state.sightings.length);
  ui.highestThreat.textContent = highestThreat();
  ui.daysSurvived.textContent = String(state.daysSurvived);
  ui.supplyHealth.textContent = supplyHealthSummary();
}

function renderSightings() {
  const threatFilter = $("filterThreat").value;
  const locFilter = $("filterLocation").value.trim().toLowerCase();
  const dateFilter = $("filterDate").value;

  const filtered = state.sightings.filter((s) => {
    const matchThreat = threatFilter === "All" || s.threat === threatFilter;
    const matchLocation = !locFilter || s.location.toLowerCase().includes(locFilter);
    const matchDate = !dateFilter || isoDateOnly(s.timestamp) === dateFilter;
    return matchThreat && matchLocation && matchDate;
  });

  ui.sightingsList.innerHTML = "";
  if (!filtered.length) {
    ui.sightingsList.innerHTML = "<li>No sightings match current filters.</li>";
    return;
  }

  filtered
    .sort((a, b) => +new Date(b.timestamp) - +new Date(a.timestamp))
    .forEach((s) => {
      const li = document.createElement("li");
      li.innerHTML = `
        <strong>${s.location}</strong> — ${s.threat}
        <div class="meta">${new Date(s.timestamp).toLocaleString()} • ${s.count} zombies • ${s.type}</div>
        <div>${s.notes || "No notes."}</div>
      `;
      const actions = $("listItemActions").content.cloneNode(true);
      actions.querySelector(".edit").addEventListener("click", () => editSighting(s.id));
      actions.querySelector(".delete").addEventListener("click", () => deleteSighting(s.id));
      li.append(actions);
      ui.sightingsList.appendChild(li);
    });
}

function renderMapList() {
  const withCoords = state.sightings.filter((s) => s.coords).slice(-5).reverse();
  ui.mapList.innerHTML = withCoords.length
    ? withCoords
        .map(
          (s) =>
            `<li>${s.location} (${s.coords.lat.toFixed(3)}, ${s.coords.lng.toFixed(3)}) - <strong>${s.threat}</strong></li>`
        )
        .join("")
    : "<li>No GPS sightings logged yet.</li>";
}

function renderSafeZones() {
  ui.safeZonesList.innerHTML = "";
  if (!state.safeZones.length) {
    ui.safeZonesList.innerHTML = "<li class='safe'>No safe zones recorded.</li>";
    return;
  }

  state.safeZones.forEach((z) => {
    const li = document.createElement("li");
    li.classList.add("safe");
    li.innerHTML = `
      <strong>${z.name}</strong>
      <div class="meta">Capacity: ${z.capacity}</div>
      <div>Supplies: ${z.supplies}</div>
      <div>${z.notes || "No notes."}</div>
    `;
    const actions = $("listItemActions").content.cloneNode(true);
    actions.querySelector(".edit").addEventListener("click", () => editSafeZone(z.id));
    actions.querySelector(".delete").addEventListener("click", () => deleteSafeZone(z.id));
    li.append(actions);
    ui.safeZonesList.appendChild(li);
  });
}

function renderSupplies() {
  ui.supplyList.innerHTML = "";
  state.supplies.forEach((s) => {
    const li = document.createElement("li");
    const isLow = s.quantity <= s.threshold;
    li.innerHTML = `
      <strong>${s.category}</strong>
      <div class="meta">Qty: ${s.quantity} • Threshold: ${s.threshold}</div>
      ${isLow ? "<div class='low-supply'>Low supply warning</div>" : ""}
    `;
    const actions = $("listItemActions").content.cloneNode(true);
    actions.querySelector(".edit").addEventListener("click", () => editSupply(s.id));
    actions.querySelector(".delete").addEventListener("click", () => deleteSupply(s.id));
    li.append(actions);
    ui.supplyList.appendChild(li);
  });
}

function renderAll() {
  renderStats();
  renderSightings();
  renderMapList();
  renderSafeZones();
  renderSupplies();
}

function handleSightingSubmit(event) {
  event.preventDefault();
  const payload = {
    id: crypto.randomUUID(),
    location: $("sightingLocation").value.trim(),
    threat: $("sightingThreat").value,
    count: Number($("sightingCount").value),
    type: $("sightingType").value,
    notes: $("sightingNotes").value.trim(),
    timestamp: new Date().toISOString(),
    coords: handleSightingSubmit.pendingCoords || null,
  };

  state.sightings.push(payload);
  if (payload.threat === "High" || payload.threat === "Critical") {
    showAlert(`⚠️ ${payload.threat} threat logged at ${payload.location}. Immediate caution advised.`);
  }

  event.target.reset();
  handleSightingSubmit.pendingCoords = null;
  persist();
  renderAll();
}

function handleSafeZoneSubmit(event) {
  event.preventDefault();
  state.safeZones.push({
    id: crypto.randomUUID(),
    name: $("safeName").value.trim(),
    supplies: $("safeSupplies").value.trim(),
    capacity: Number($("safeCapacity").value),
    notes: $("safeNotes").value.trim(),
  });
  event.target.reset();
  persist();
  renderAll();
}

function handleSupplySubmit(event) {
  event.preventDefault();
  const category = $("supplyCategory").value;
  const quantity = Number($("supplyQuantity").value);
  const threshold = Number($("supplyThreshold").value);

  const existing = state.supplies.find((s) => s.category === category);
  if (existing) {
    existing.quantity = quantity;
    existing.threshold = threshold;
  } else {
    state.supplies.push({ id: crypto.randomUUID(), category, quantity, threshold });
  }

  if (quantity <= threshold) {
    showAlert(`⚠️ ${category} is at or below threshold.`);
  }

  event.target.reset();
  persist();
  renderAll();
}

function editSighting(id) {
  const item = state.sightings.find((s) => s.id === id);
  if (!item) return;
  const location = prompt("Edit location:", item.location);
  if (location === null) return;
  const notes = prompt("Edit notes:", item.notes || "");
  if (notes === null) return;
  item.location = location.trim() || item.location;
  item.notes = notes.trim();
  persist();
  renderAll();
}

function deleteSighting(id) {
  state.sightings = state.sightings.filter((s) => s.id !== id);
  persist();
  renderAll();
}

function editSafeZone(id) {
  const item = state.safeZones.find((z) => z.id === id);
  if (!item) return;
  const name = prompt("Edit safe zone name:", item.name);
  if (name === null) return;
  item.name = name.trim() || item.name;
  persist();
  renderAll();
}

function deleteSafeZone(id) {
  state.safeZones = state.safeZones.filter((z) => z.id !== id);
  persist();
  renderAll();
}

function editSupply(id) {
  const item = state.supplies.find((s) => s.id === id);
  if (!item) return;
  const qty = prompt(`Edit quantity for ${item.category}:`, String(item.quantity));
  if (qty === null) return;
  const threshold = prompt(`Edit threshold for ${item.category}:`, String(item.threshold));
  if (threshold === null) return;
  item.quantity = Number(qty);
  item.threshold = Number(threshold);
  persist();
  renderAll();
}

function deleteSupply(id) {
  state.supplies = state.supplies.filter((s) => s.id !== id);
  persist();
  renderAll();
}

function setupFilters() {
  ["filterThreat", "filterLocation", "filterDate"].forEach((id) => {
    $(id).addEventListener("input", renderSightings);
  });
}

function setupGeolocation() {
  $("gpsButton").addEventListener("click", () => {
    if (!navigator.geolocation) {
      showAlert("Geolocation unavailable on this device/browser.");
      return;
    }

    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const { latitude, longitude } = pos.coords;
        handleSightingSubmit.pendingCoords = { lat: latitude, lng: longitude };
        $("sightingLocation").value = `Lat ${latitude.toFixed(4)}, Lng ${longitude.toFixed(4)}`;
        showAlert("GPS coordinates captured for next sighting.");
      },
      () => showAlert("Unable to access GPS coordinates."),
      { enableHighAccuracy: true, timeout: 8000 }
    );
  });
}

function setupDataOps() {
  $("exportBtn").addEventListener("click", () => {
    const blob = new Blob([JSON.stringify(state, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `z-tracker-backup-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
  });

  $("importInput").addEventListener("change", async (event) => {
    const file = event.target.files?.[0];
    if (!file) return;

    try {
      const text = await file.text();
      const incoming = JSON.parse(text);
      state = {
        ...structuredClone(defaultState),
        ...incoming,
        sightings: incoming.sightings || [],
        safeZones: incoming.safeZones || [],
        supplies: incoming.supplies || [],
      };
      persist();
      renderAll();
      showAlert("Data import successful.");
    } catch {
      showAlert("Import failed. Invalid JSON format.");
    } finally {
      event.target.value = "";
    }
  });

  $("resetBtn").addEventListener("click", () => {
    const confirmed = confirm("Reset all Z-Tracker data?");
    if (!confirmed) return;
    state = structuredClone(defaultState);
    persist();
    renderAll();
  });
}

function setupDaysCounter() {
  $("increaseDays").addEventListener("click", () => {
    state.daysSurvived += 1;
    persist();
    renderStats();
  });

  $("decreaseDays").addEventListener("click", () => {
    state.daysSurvived = Math.max(0, state.daysSurvived - 1);
    persist();
    renderStats();
  });
}

function init() {
  $("sightingForm").addEventListener("submit", handleSightingSubmit);
  $("safeZoneForm").addEventListener("submit", handleSafeZoneSubmit);
  $("supplyForm").addEventListener("submit", handleSupplySubmit);

  setupFilters();
  setupGeolocation();
  setupDataOps();
  setupDaysCounter();

  renderAll();
}

init();
