// ── Bottom-left tab switching ─────────────────────────────────────────────────
function switchBLTab(tab) {
  document.querySelectorAll('.bl-tab').forEach(function(t) {
    t.classList.remove('active');
  });
  document.querySelectorAll('.bl-panel').forEach(function(p) {
    p.classList.remove('active');
  });
  var tabEl   = document.querySelector('.bl-tab[onclick*="' + tab + '"]');
  var panelEl = document.getElementById('bl_' + tab);
  if (tabEl)   tabEl.classList.add('active');
  if (panelEl) panelEl.classList.add('active');
}

// ── Splitter state ────────────────────────────────────────────────────────────
var splitterState = { plotPct: 0.6, leftPct: 0.5, dragging: null };

function applyLayout() {
  var analysis    = document.getElementById('main_analysis');
  var plotPane    = document.getElementById('plot_pane');
  var bottomRow   = document.getElementById('bottom_row');
  var bottomLeft  = document.getElementById('bottom_left');
  var bottomRight = document.getElementById('bottom_right');
  var hSplit      = document.getElementById('h_splitter');
  var vSplit      = document.getElementById('v_splitter');

  if (!analysis || analysis.style.display === 'none') return;

  var totalH    = analysis.clientHeight;
  var hSplitH   = hSplit ? hSplit.offsetHeight : 6;
  var remaining = totalH - hSplitH - 8;
  var plotH     = Math.max(200, Math.round(remaining * splitterState.plotPct));
  var bottomH   = Math.max(150, remaining - plotH);

  plotPane.style.height  = plotH + 'px';
  bottomRow.style.height = bottomH + 'px';

  var totalW  = bottomRow.clientWidth;
  var vSplitW = vSplit ? vSplit.offsetWidth : 6;
  var availW  = totalW - vSplitW;
  var leftW   = Math.max(200, Math.round(availW * splitterState.leftPct));
  var rightW  = Math.max(200, availW - leftW);

  bottomLeft.style.width       = leftW + 'px';
  bottomLeft.style.flexShrink  = '0';
  bottomRight.style.width      = rightW + 'px';
  bottomRight.style.flexShrink = '0';

  resizePlotly();
}

function resizePlotly() {
  setTimeout(function() {
    document.querySelectorAll('.js-plotly-plot').forEach(function(p) {
      Plotly.Plots.resize(p);
    });
  }, 30);
}

// ── Compute button state ──────────────────────────────────────────────────────
function setComputing(on) {
  var btn       = document.getElementById('compute');
  var computing = document.getElementById('plot_computing');
  if (on) {
    btn.disabled    = true;
    btn.textContent = 'Computing...';
    computing.style.display = 'flex';
  } else {
    btn.disabled    = false;
    btn.textContent = 'Compute';
    computing.style.display = 'none';
  }
}

Shiny.addCustomMessageHandler('compute_done', function(msg) {
  setComputing(false);
  if (msg.is_corr) {
    document.getElementById('corr_loading').style.display     = 'none';
    document.getElementById('corr_plot_wrap').style.display   = 'block';
    document.getElementById('download_corr_btn').style.display = 'inline-block';
    var pane = document.getElementById('plot_pane');
    Shiny.setInputValue('corr_plot_width',  pane.clientWidth);
    Shiny.setInputValue('corr_plot_height', pane.clientHeight);
  }
});

Shiny.addCustomMessageHandler('show_corr', function(msg) {
  var overlay  = document.getElementById('corr_overlay');
  var loading  = document.getElementById('corr_loading');
  var plotWrap = document.getElementById('corr_plot_wrap');
  var dlBtn    = document.getElementById('download_corr_btn');
  if (msg.show) {
    overlay.style.display  = 'block';
    loading.style.display  = 'flex';
    plotWrap.style.display = 'none';
    dlBtn.style.display    = 'none';
  } else {
    overlay.style.display  = 'none';
    dlBtn.style.display    = 'none';
  }
});

// ── noUiSlider time range sliders ─────────────────────────────────────────────
var sliderInstances = {};

function minsToLabel(m) {
  m = Math.round(m);
  return String(Math.floor(m / 60)).padStart(2, '0') + ':' +
         String(m % 60).padStart(2, '0');
}

function initSlider(elId, shinyId, labelId) {
  var el      = document.getElementById(elId);
  var labelEl = document.getElementById(labelId);
  if (!el) return;

  var STEP     = 15;
  var MAX_MINS = 1439;

  var slider = noUiSlider.create(el, {
    start:     [0, MAX_MINS],
    connect:   true,
    step:      STEP,
    range:     { min: 0, max: MAX_MINS },
    behaviour: 'drag-tap'
  });

  sliderInstances[shinyId] = slider;

  slider.on('update', function(values) {
    var lo = Math.round(parseFloat(values[0]));
    var hi = Math.round(parseFloat(values[1]));
    if (labelEl) {
      labelEl.textContent = minsToLabel(lo) + ' - ' + minsToLabel(hi);
    }
  });

  slider.on('change', function(values) {
    var lo = Math.round(parseFloat(values[0]));
    var hi = Math.round(parseFloat(values[1]));
    Shiny.setInputValue(shinyId, [lo, hi], {priority: 'event'});
  });

  // Push initial value immediately
  Shiny.setInputValue(shinyId, [0, MAX_MINS], {priority: 'event'});
  if (labelEl) labelEl.textContent = '00:00 - 23:59';
}

Shiny.addCustomMessageHandler('reset_time_sliders', function(msg) {
  var MAX_MINS = 1439;
  Object.keys(sliderInstances).forEach(function(shinyId) {
    sliderInstances[shinyId].set([0, MAX_MINS]);
    Shiny.setInputValue(shinyId, [0, MAX_MINS], {priority: 'event'});
  });
  var l1 = document.getElementById('time_range_label_txt');
  var l2 = document.getElementById('plot_time_range_label_txt');
  if (l1) l1.textContent = '00:00 - 23:59';
  if (l2) l2.textContent = '00:00 - 23:59';
});

// ── Dual cascade filter state ─────────────────────────────────────────────────
var filterCombos     = [];
var filterCols       = [];
var analysisSelected = {};
var plotSelected     = {};

Shiny.addCustomMessageHandler('init_filters', function(msg) {
  filterCombos = msg.combos;
  filterCols   = msg.cols;

  analysisSelected = {};
  plotSelected     = {};

  filterCols.forEach(function(col) {
    var allVals = new Set(filterCombos.map(function(r) { return r[col]; }));
    analysisSelected[col] = new Set(allVals);
    plotSelected[col]     = new Set(allVals);
  });

  renderAnalysisFilters();
  renderPlotFilters();
  pushAnalysisFiltersToShiny();
  pushPlotFiltersToShiny();
});

function analysisAvailableFor(col) {
  var otherCols = filterCols.filter(function(c) { return c !== col; });
  var available = new Set();
  filterCombos.forEach(function(row) {
    var pass = otherCols.every(function(c) {
      return analysisSelected[c].has(row[c]);
    });
    if (pass) available.add(row[col]);
  });
  return available;
}

function plotAvailableFor(col) {
  var otherPlotCols = filterCols.filter(function(c) { return c !== col; });
  var available = new Set();
  filterCombos.forEach(function(row) {
    var passAnalysis = filterCols.every(function(c) {
      return analysisSelected[c].has(row[c]);
    });
    var passOtherPlot = otherPlotCols.every(function(c) {
      return plotSelected[c].has(row[c]);
    });
    if (passAnalysis && passOtherPlot) available.add(row[col]);
  });
  return available;
}

function renderAnalysisFilters() {
  var container = document.getElementById('analysis_filters_container');
  if (!container) return;
  container.innerHTML = '';
  renderFilterBlock(container, filterCols, analysisSelected,
                    analysisAvailableFor, 'analysis');
}

function renderPlotFilters() {
  var container = document.getElementById('plot_filters_container');
  if (!container) return;
  container.innerHTML = '';
  renderFilterBlock(container, filterCols, plotSelected,
                    plotAvailableFor, 'plot');
}

function syncPlotToAnalysis() {
  filterCols.forEach(function(col) {
    var avail = plotAvailableFor(col);
    plotSelected[col].forEach(function(v) {
      if (!avail.has(v)) plotSelected[col].delete(v);
    });
    avail.forEach(function(v) { plotSelected[col].add(v); });
  });
  renderPlotFilters();
  pushPlotFiltersToShiny();
}

function renderFilterBlock(container, cols, selected, availableFn, prefix) {
  cols.forEach(function(col) {
    var available = availableFn(col);
    var allVals   = Array.from(new Set(
      filterCombos.map(function(r) { return r[col]; })
    )).sort();

    var header = document.createElement('div');
    header.className = 'filter-header';
    header.style.marginTop = '8px';

    var label = document.createElement('span');
    label.className = 's-label';
    label.style.margin = '0';
    label.textContent = col;

    var links = document.createElement('div');
    links.className = 'filter-header-links';

    var allBtn = document.createElement('button');
    allBtn.className = 'filter-link';
    allBtn.textContent = 'all';
    allBtn.onclick = (function(c, avail) {
      return function() {
        selected[c] = new Set(avail);
        if (prefix === 'analysis') {
          renderAnalysisFilters();
          pushAnalysisFiltersToShiny();
          syncPlotToAnalysis();
        } else {
          renderPlotFilters();
          pushPlotFiltersToShiny();
        }
      };
    })(col, Array.from(available));

    var noneBtn = document.createElement('button');
    noneBtn.className = 'filter-link none';
    noneBtn.textContent = 'none';
    noneBtn.onclick = (function(c) {
      return function() {
        selected[c] = new Set();
        if (prefix === 'analysis') {
          renderAnalysisFilters();
          pushAnalysisFiltersToShiny();
          syncPlotToAnalysis();
        } else {
          renderPlotFilters();
          pushPlotFiltersToShiny();
        }
      };
    })(col);

    links.appendChild(allBtn);
    links.appendChild(noneBtn);
    header.appendChild(label);
    header.appendChild(links);
    container.appendChild(header);

    var box = document.createElement('div');
    box.className = 'meta-filter-box';

    allVals.forEach(function(val) {
      var isAvailable = available.has(val);
      var isChecked   = selected[col].has(val);

      var row = document.createElement('label');
      row.className = 'cb-row';
      if (!isAvailable) {
        row.style.opacity = '0.35';
        row.style.cursor  = 'not-allowed';
      }

      var cb = document.createElement('input');
      cb.type     = 'checkbox';
      cb.checked  = isChecked;
      cb.disabled = !isAvailable;

      cb.onchange = (function(c, v, sel, pref) {
        return function() {
          if (this.checked) {
            sel[c].add(v);
          } else {
            sel[c].delete(v);
          }
          if (pref === 'analysis') {
            renderAnalysisFilters();
            pushAnalysisFiltersToShiny();
            syncPlotToAnalysis();
          } else {
            renderPlotFilters();
            pushPlotFiltersToShiny();
          }
        };
      })(col, val, selected, prefix);

      var lbl = document.createElement('span');
      lbl.textContent = val;
      if (!isAvailable) lbl.style.color = '#bbb';

      row.appendChild(cb);
      row.appendChild(lbl);
      box.appendChild(row);
    });

    container.appendChild(box);
  });
}

function pushAnalysisFiltersToShiny() {
  filterCols.forEach(function(col) {
    var available  = analysisAvailableFor(col);
    var activeVals = Array.from(analysisSelected[col]).filter(function(v) {
      return available.has(v);
    });
    Shiny.setInputValue('analysis_filter_' + col, activeVals,
                        {priority: 'event'});
  });
}

function pushPlotFiltersToShiny() {
  filterCols.forEach(function(col) {
    var available  = plotAvailableFor(col);
    var activeVals = Array.from(plotSelected[col]).filter(function(v) {
      return available.has(v);
    });
    Shiny.setInputValue('plot_filter_' + col, activeVals,
                        {priority: 'event'});
  });
}

function selectAllIndices() {
  Shiny.setInputValue('indices_select_all', Math.random());
}
function deselectAllIndices() {
  Shiny.setInputValue('indices_deselect_all', Math.random());
}

// ── DOMContentLoaded ──────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', function() {


  var sidebar        = document.getElementById('sidebar');
  var resizeHandle   = document.getElementById('sidebar_resize');
  var resizeDragging = false;

  resizeHandle.addEventListener('mousedown', function(e) {
    resizeDragging = true;
    resizeHandle.classList.add('dragging');
    e.preventDefault();
  });

  document.getElementById('compute').addEventListener('click', function() {
    setComputing(true);
  });

  document.addEventListener('mousemove', function(e) {
    if (resizeDragging) {
      var newW = Math.min(400, Math.max(160, e.clientX));
      sidebar.style.width = newW + 'px';
      applyLayout();
      resizePlotly();
    }
    if (splitterState.dragging === 'h') {
      var analysis = document.getElementById('main_analysis');
      splitterState.plotPct = Math.min(0.85, Math.max(0.15,
        (e.clientY - analysis.getBoundingClientRect().top) /
        analysis.clientHeight));
      applyLayout();
      resizePlotly();
    } else if (splitterState.dragging === 'v') {
      var bottomRow = document.getElementById('bottom_row');
      splitterState.leftPct = Math.min(0.85, Math.max(0.15,
        (e.clientX - bottomRow.getBoundingClientRect().left) /
        bottomRow.clientWidth));
      applyLayout();
      resizePlotly();
    }
  });

  document.addEventListener('mouseup', function() {
    if (resizeDragging) {
      resizeDragging = false;
      resizeHandle.classList.remove('dragging');
      resizePlotly();
    }
    if (splitterState.dragging) {
      document.getElementById('h_splitter').classList.remove('dragging');
      document.getElementById('v_splitter').classList.remove('dragging');
      splitterState.dragging = null;
      resizePlotly();
    }
  });

  var hSplit = document.getElementById('h_splitter');
  var vSplit = document.getElementById('v_splitter');

  hSplit.addEventListener('mousedown', function(e) {
    splitterState.dragging = 'h';
    hSplit.classList.add('dragging');
    e.preventDefault();
  });

  vSplit.addEventListener('mousedown', function(e) {
    splitterState.dragging = 'v';
    vSplit.classList.add('dragging');
    e.preventDefault();
  });

  applyLayout();
  window.addEventListener('resize', applyLayout);
});


// ── Tab switching + Sliders ─────────────────────────────────────────────────────────────

var slidersInitialised = false;

function switchTab(tab) {
  document.getElementById('tab_setup').classList.remove('active');
  document.getElementById('tab_analysis').classList.remove('active');
  document.getElementById('tab_' + tab).classList.add('active');
  document.getElementById('panel_setup').style.display =
    tab === 'setup' ? 'block' : 'none';
  document.getElementById('panel_analysis').style.display =
    tab === 'analysis' ? 'block' : 'none';
  document.getElementById('main_setup').style.display =
    tab === 'setup' ? 'block' : 'none';
  document.getElementById('main_analysis').style.display =
    tab === 'analysis' ? 'flex' : 'none';
  if (tab === 'analysis') {
    if (!slidersInitialised) {
      initSlider('time_range_slider',      'time_range',      'time_range_label_txt');
      initSlider('plot_time_range_slider', 'plot_time_range', 'plot_time_range_label_txt');
      slidersInitialised = true;
    }
    setTimeout(applyLayout, 50);
  }
}

// ── Wavesurfer ────────────────────────────────────────────────────────────────
$(document).ready(function() {

  var wavesurfer = WaveSurfer.create({
    container:     '#waveform',
    waveColor:     '#a78bfa',
    progressColor: '#7c3aed',
    cursorColor:   '#333',
    height:        80,
    sampleRate:    44100,
    plugins: [
      WaveSurfer.Spectrogram.create({
        container:    '#spectrogram',
        fftSamples:   512,
        labels:       true,
        frequencyMax: 22050
      })
    ]
  });

  var isPlaying = false;

  $('#play_pause').click(function() {
    isPlaying ? wavesurfer.pause() : wavesurfer.play();
    isPlaying = !isPlaying;
  });

  Shiny.addCustomMessageHandler('update_audio', function(msg) {
    wavesurfer.load(msg.src);
    wavesurfer.on('ready', function() {
      wavesurfer.play();
      isPlaying = true;
    });
  });

  Shiny.addCustomMessageHandler('update_now_playing', function(msg) {
    $('#now_playing_text').html(msg.info);
    $('#buttons_container').removeClass('hidden');
  });

  Shiny.addCustomMessageHandler('set_analysis_enabled', function(msg) {
    var tab = document.getElementById('tab_analysis');
    if (msg.enabled) {
      tab.classList.remove('disabled-tab');
    } else {
      tab.classList.add('disabled-tab');
    }
  });

});