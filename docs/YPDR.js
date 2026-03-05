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
    const geoResponse = await fetch('data/state_boundaries.geojson');
    statesDataGlobal = await geoResponse.json();

    // Load CSV using PapaParse
    Papa.parse("data/testdata.csv", {
        download: true,
        header: true,
        skipEmptyLines: true,
        complete: function(results) {
            allData = results.data;
            
            // Initialize All Filters
            populateFilter('yearFilter', 'year');
            populateFilter('statusFilter', 'status');
            populateFilter('stateFilter', 'state');
            
            // Initial Draw
            updateDashboard();
            
            // Add Event Listeners to all dropdowns
            ['yearFilter', 'statusFilter', 'stateFilter'].forEach(id => {
                document.getElementById(id).addEventListener('change', () => {
                    updateDashboard();
                });
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

                    // 3. Format the breakdown string for the popup
                    const statusSummary = `Passed: ${counts["passed"]}, ` +
                                         `In Progress: ${counts["in progress"]}, ` +
                                         `Failed: ${counts["failed"]}`;

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
                    document.getElementById('stateFilter').value = stateName;
                    updateDashboard();
                    map.fitBounds(e.target.getBounds());
                }
            });
        }
    }).addTo(map);
}

init();