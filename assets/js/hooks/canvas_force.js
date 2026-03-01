import {
  forceSimulation,
  forceCenter,
  forceManyBody,
  forceCollide,
} from "d3-force";

// Stage -> DaisyUI classes for circle appearance
const STAGE_CLASSES = {
  complete: "bg-success text-success-content border-2 border-success-content/20",
  lobby: "bg-base-100 text-base-content border-2 border-base-300",
  _default: "bg-primary text-primary-content border-2 border-primary-content/20",
};

function stageClasses(stage) {
  return STAGE_CLASSES[stage] || STAGE_CLASSES._default;
}

const CanvasForce = {
  mounted() {
    this.container = this.el;
    this.nodeEls = {};

    // Create the + button as a fixed node at center
    this.centerNode = { id: "__center__", fx: 0, fy: 0, size: 24, fixed: true };

    this.sim = forceSimulation()
      .force("charge", forceManyBody().strength(-300))
      .force("center", forceCenter(0, 0))
      .force("collide", forceCollide((d) => d.size + 6).strength(1))
      .alphaDecay(0.02)
      .on("tick", () => {
        this.clampToBounds();
        this.render();
      });

    // Receive circle data from LiveView
    this.handleEvent("circles_updated", ({ circles }) => {
      this.updateNodes(circles);
    });

    // Handle window resize - reheat simulation so nodes reflow into new bounds
    this.resizeObserver = new ResizeObserver(() => {
      this.sim.alpha(0.3).restart();
    });
    this.resizeObserver.observe(this.container);
  },

  destroyed() {
    this.sim.stop();
    if (this.resizeObserver) this.resizeObserver.disconnect();
  },

  updateNodes(circles) {
    // circles is a list of {id, title, tagline, stage, size}
    // Convert to d3 nodes, preserving existing positions where possible
    const existing = {};
    for (const node of this.sim.nodes()) {
      existing[node.id] = node;
    }

    const nodes = [this.centerNode];

    // Sort by ID so all clients get the same initial positions
    const sorted = [...circles].sort((a, b) => a.id.localeCompare(b.id));

    for (let i = 0; i < sorted.length; i++) {
      const c = sorted[i];
      const prev = existing[c.id];
      // Deterministic initial position: spread evenly in a circle around center
      const angle = (i / sorted.length) * 2 * Math.PI;
      const r = 80;
      nodes.push({
        id: c.id,
        title: c.title,
        tagline: c.tagline,
        stage: c.stage,
        size: c.size || 48,
        x: prev ? prev.x : Math.cos(angle) * r,
        y: prev ? prev.y : Math.sin(angle) * r,
        vx: prev ? prev.vx : 0,
        vy: prev ? prev.vy : 0,
      });
    }

    this.sim.nodes(nodes);
    this.sim.alpha(0.5).restart();

    // Remove DOM elements for nodes that no longer exist
    const activeIds = new Set(circles.map((c) => c.id));
    for (const id of Object.keys(this.nodeEls)) {
      if (!activeIds.has(id)) {
        this.nodeEls[id].remove();
        delete this.nodeEls[id];
      }
    }
  },

  clampToBounds() {
    const w = this.container.clientWidth;
    const h = this.container.clientHeight;
    const pad = 72; // circle radius (64) + margin (8)
    const halfW = w / 2 - pad;
    const halfH = h / 2 - pad;

    for (const node of this.sim.nodes()) {
      if (node.fixed) continue;
      node.x = Math.max(-halfW, Math.min(halfW, node.x));
      node.y = Math.max(-halfH, Math.min(halfH, node.y));
    }
  },

  render() {
    const w = this.container.clientWidth;
    const h = this.container.clientHeight;
    const cx = w / 2;
    const cy = h / 2;

    for (const node of this.sim.nodes()) {
      if (node.id === "__center__") continue;

      let el = this.nodeEls[node.id];
      if (!el) {
        el = document.createElement("a");
        el.href = `/d/${node.id}`;
        el.className = `absolute z-10 flex flex-col items-center justify-center rounded-full shadow-xl
                        cursor-pointer w-32 h-32 text-center
                        hover:scale-110 hover:shadow-2xl transition-shadow duration-200 ${stageClasses(node.stage)}`;
        el.innerHTML = `
          <span class="font-bold text-xs px-2 leading-tight line-clamp-2"></span>
          <span class="text-xs opacity-70 px-2 mt-1 leading-tight line-clamp-2"></span>
        `;
        this.container.appendChild(el);
        this.nodeEls[node.id] = el;
      }

      // Update content
      const titleEl = el.querySelector("span:first-child");
      const taglineEl = el.querySelector("span:last-child");
      titleEl.textContent = node.title || "";
      if (node.tagline) {
        taglineEl.textContent = node.tagline;
        taglineEl.style.display = "";
      } else {
        taglineEl.style.display = "none";
      }

      // Update stage classes
      const newClasses = stageClasses(node.stage);
      if (el.dataset.stage !== node.stage) {
        // Strip old stage classes and apply new ones
        el.className = `absolute z-10 flex flex-col items-center justify-center rounded-full shadow-xl
                        cursor-pointer w-32 h-32 text-center
                        hover:scale-110 hover:shadow-2xl transition-shadow duration-200 ${newClasses}`;
        el.dataset.stage = node.stage;
      }

      // Position: d3 coordinates (centered at 0,0) -> viewport pixels
      const px = cx + node.x;
      const py = cy + node.y;
      el.style.transform = `translate(${px - 64}px, ${py - 64}px)`;
    }
  },
};

export default CanvasForce;
