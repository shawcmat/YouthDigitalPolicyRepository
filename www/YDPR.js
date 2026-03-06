let allData = [];
let geoLayer;
let map;
let statesDataGlobal; // Store geojson globally for easy access


const colors = {
    "passed": "#184D47",
    "failed": "#C64756",
    "in progress": "#FAD586",
    "none": "#808080"
};

// Initialize Map
map = L.map('map').setView([37.8, -96], 4);
L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png').addTo(map);

// Load Data
async function init() {
    const geoResponse = await fetch('www/data/state_boundaries.geojson');
    statesDataGlobal = await geoResponse.json();

    // Load CSV using PapaParse
    Papa.parse("YDPR_Data.csv", {
        download: true,
        header: true,
        skipEmptyLines: true,
        complete: function(results) {
            allData = results.data;
            
            // Initialize All Filters
            populateFilter('yearFilter', 'year');
            populateFilter('statusFilter', 'status');

            // Populate state filter from GeoJSON so all states appear,
            // even those with zero policies in the dataset
            const allStateNames = statesDataGlobal.features
                .map(f => f.properties.name)
                .sort();
            const stateSelect = document.getElementById('stateFilter');
            allStateNames.forEach(name => {
                const opt = document.createElement('option');
                opt.value = name;
                opt.innerHTML = name;
                stateSelect.appendChild(opt);
            });
            
            // Initial Draw
            updateDashboard();
            
            // Add Event Listeners to all dropdowns
            ['yearFilter', 'statusFilter', 'stateFilter'].forEach(id => {
                document.getElementById(id).addEventListener('change', () => {
                    updateDashboard();
                });
            });

            // Reset all filters to 'All' and re-center map
            document.getElementById('resetFilters').addEventListener('click', () => {
                ['yearFilter', 'statusFilter', 'stateFilter'].forEach(id => {
                    document.getElementById(id).value = 'All';
                });
                map.setView([37.8, -96], 4);
                updateDashboard();
            });
        }
    });
}

// Generic function to populate any dropdown based on CSV column keys
function populateFilter(elementId, dataKey) {
    const uniqueValues = [...new Set(allData.map(d => d[dataKey]))].filter(v => v).sort();
    const select = document.getElementById(elementId);
    
    uniqueValues.forEach(val => {
        let opt = document.createElement('option');
        opt.value = val;
        opt.innerHTML = val;
        select.appendChild(opt);
    });
}

function updateDashboard() {
    const yearVal = document.getElementById('yearFilter').value;
    const statusVal = document.getElementById('statusFilter').value;
    const stateVal = document.getElementById('stateFilter').value;

    const filtered = allData.filter(d => {
        const matchYear = (yearVal === "All" || d.year === yearVal);
        const matchStatus = (statusVal === "All" || d.status === statusVal);
        const matchState = (stateVal === "All" || d.state === stateVal);
        return matchYear && matchStatus && matchState;
    });

    // Update Table
    if ($.fn.DataTable.isDataTable('#billTable')) {
        $('#billTable').DataTable().destroy();
    }

    $('#billTable').DataTable({
        data: filtered,
        columns: [
            { data: 'state' },
            { data: 'year' },
            { 
                data: 'statute_number',
                // This function transforms the raw data into a clickable link
                render: function(data, type, row) {
                    if (row.url && row.url.trim() !== "") {
                        // 'target="_blank"' opens the policy in a new tab
                        return `<a href="${row.url}" target="_blank" class="policy-link">${data}</a>`;
                    }
                    return data; // Fallback to plain text if no URL is provided
                }
            },
            { data: 'status' }
        ]
    });

    if (geoLayer) map.removeLayer(geoLayer);

    geoLayer = L.geoJson(statesDataGlobal, {
        style: function(feature) {
            const stateName = feature.properties.name;
            const statePolicies = filtered.filter(d => d.state === stateName);
            
            let winningStatus = "none";
            if (statePolicies.length > 0) {
                const statuses = statePolicies.map(p => p.status.toLowerCase());
                if (statuses.includes("passed")) winningStatus = "passed";
                else if (statuses.includes("in progress")) winningStatus = "in progress";
                else if (statuses.includes("failed")) winningStatus = "failed";
            }
            
            return {
                fillColor: colors[winningStatus] || colors["none"],
                weight: 1, opacity: 1, color: 'white',
                fillOpacity: statePolicies.length > 0 ? 0.9 : 0.2
            };
        },
        onEachFeature: function(feature, layer) {
            const stateName = feature.properties.name;
            
            layer.on({
                mouseover: function(e) {
                    const targetLayer = e.target;
                    targetLayer.setStyle({ weight: 3, color: '#666', fillOpacity: 1 });

                    // 1. Filter policies for THIS state
                    const statePolicies = filtered.filter(d => d.state === stateName);

                    // 2. Count each status specifically
                    const counts = { "passed": 0, "in progress": 0, "failed": 0 };
                    statePolicies.forEach(p => {
                        const s = p.status.toLowerCase();
                        if (counts.hasOwnProperty(s)) counts[s]++;
                    });

                    // 3. Format the breakdown string, only including statuses with a non-zero count
                    const labels = { "passed": "Passed", "in progress": "In Progress", "failed": "Failed" };
                    const statusSummary = Object.entries(counts)
                        .filter(([, count]) => count > 0)
                        .map(([status, count]) => `${labels[status]}: ${count}`)
                        .join(', ');

                    targetLayer.bindPopup(`<strong>${stateName}</strong><br>${statusSummary}`, {
                        closeButton: false,
                        offset: L.point(0, -10)
                    }).openPopup();
                },
                mouseout: function(e) {
                    geoLayer.resetStyle(e.target);
                    e.target.closePopup();
                },
                click: function(e) {
                    const stateFilter = document.getElementById('stateFilter');
                    // If this state is already selected, reset to All; otherwise select it
                    stateFilter.value = (stateFilter.value === stateName) ? 'All' : stateName;
                    updateDashboard();
                    if (stateFilter.value == 'All'){
                        map.setView([37.8, -96], 4);
                    }else{}
                    map.fitBounds(e.target.getBounds());
                }
            });
        }
    }).addTo(map);
}

// Shared function to switch the active view and update navbar highlighting.
// Called by both navbar links and any in-content links that target a section ID.
// pushHistory: set to false when called from popstate (browser back/forward),
// so we don't push a duplicate entry onto the history stack.
function switchView(targetId, pushHistory = true) {
    // 1. Remove 'active-view' from all sections
    document.querySelectorAll('.view').forEach(view => {
        view.classList.remove('active-view');
    });

    // 2. Add 'active-view' to the target section
    const targetSection = document.getElementById(targetId);
    if (targetSection) {
        targetSection.classList.add('active-view');
    }

    // 3. Update Navbar highlighting to match the active section
    document.querySelectorAll('.nav-links a').forEach(nav => {
        const navTarget = nav.getAttribute('href').substring(1);
        nav.classList.toggle('active', navTarget === targetId);
    });

    // 4. Fix Leaflet map rendering if switching back to dashboard
    if (targetId === 'dashboard' && map) {
        setTimeout(() => map.invalidateSize(), 100);
    }

    // 5. Push a history entry so the browser back/forward buttons work
    if (pushHistory) {
        history.pushState({ view: targetId }, '', `#${targetId}`);
    }
}

// When the user hits back or forward, restore the view from history state
window.addEventListener('popstate', function(e) {
    const targetId = e.state?.view ?? 'dashboard';
    switchView(targetId, false);
});

// On first load, replace the initial history entry with the current view,
// so the back button has a valid state to return to
const initialView = location.hash.substring(1) || 'dashboard';
history.replaceState({ view: initialView }, '', `#${initialView}`);

// Bind switchView to navbar links
document.querySelectorAll('.nav-links a').forEach(link => {
    link.addEventListener('click', function(e) {
        e.preventDefault();
        switchView(this.getAttribute('href').substring(1));
    });
});

// Bind switchView to any in-content links whose href matches a section ID (e.g. href="#about")
document.querySelectorAll('.view a[href^="#"]').forEach(link => {
    const targetId = link.getAttribute('href').substring(1);
    if (document.getElementById(targetId)?.classList.contains('view')) {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            switchView(targetId);
        });
    }
});

init();