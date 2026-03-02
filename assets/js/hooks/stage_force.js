import { createStageSimulation, clampToBounds, pinWinner } from "./stage_simulation";

const CANVAS_W = 1000;
const CANVAS_H = 700;
const CENTER_X = CANVAS_W / 2;
const CENTER_Y = CANVAS_H / 2;

/**
 * Scan the container for [data-node-id] elements and build node descriptors.
 * Pure-ish: takes a root element, returns an array of descriptors.
 */
export function scanCards(container) {
  const elements = container.querySelectorAll("[data-node-id]");
  const nodes = [];

  for (const el of elements) {
    const id = el.getAttribute("data-node-id");
    const role = el.getAttribute("data-node-role") || "other";
    // Measure the inner card, not the positioning wrapper
    const measure = el.firstElementChild || el;
    const w = measure.offsetWidth || 0;
    const h = measure.offsetHeight || 0;
    const halfW = w / 2;
    const halfH = h / 2;

    nodes.push({ id, role, halfW, halfH, el });
  }

  return nodes;
}

/**
 * Merge scanned nodes with existing simulation nodes.
 * Preserves x, y, vx, vy for nodes that already exist.
 * Updates radius and el reference from the scan.
 * New nodes get no position (simulation will initialize them).
 */
export function mergeNodes(existing, scanned) {
  const existingById = {};
  for (const node of existing) {
    existingById[node.id] = node;
  }

  return scanned.map((s) => {
    const prev = existingById[s.id];
    if (prev) {
      return {
        ...prev,
        halfW: s.halfW,
        halfH: s.halfH,
        el: s.el,
        role: s.role,
      };
    }
    return { ...s };
  });
}

const StageForce = {
  mounted() {
    this.nodeMap = {};

    requestAnimationFrame(() => {
      this._initSimulation();
    });
  },

  updated() {
    const scanned = scanCards(this.el);

    if (!this.sim) {
      // Simulation not yet initialized, try now
      this._initSimulation();
      return;
    }

    const merged = mergeNodes(this.sim.nodes(), scanned);

    // Determine if structure changed (nodes added or removed)
    const prevIds = new Set(this.sim.nodes().map((n) => n.id));
    const newIds = new Set(merged.map((n) => n.id));
    const structureChanged =
      prevIds.size !== newIds.size ||
      [...prevIds].some((id) => !newIds.has(id));

    if (structureChanged) {
      // Rebuild simulation so targets are recomputed for new node set
      this.sim.stop();
      const nodes = merged.map((s) => ({ ...s }));
      this.sim = createStageSimulation(nodes, CANVAS_W, CANVAS_H);
      this.sim.on("tick", () => {
        clampToBounds(this.sim.nodes(), CANVAS_W, CANVAS_H);
        this._applyPositions();
      });
    } else {
      // Update node references (el, radius) but don't reheat
      this.sim.nodes(merged);
      this._applyPositions();
    }

    // Check for winner
    this._checkWinner();
  },

  destroyed() {
    if (this.sim) this.sim.stop();
  },

  _initSimulation() {
    const scanned = scanCards(this.el);
    if (scanned.length === 0) return;

    const nodes = scanned.map((s) => ({ ...s }));

    this.sim = createStageSimulation(nodes, CANVAS_W, CANVAS_H);
    this.sim.on("tick", () => {
      clampToBounds(this.sim.nodes(), CANVAS_W, CANVAS_H);
      this._applyPositions();
    });

    this._checkWinner();
  },

  _applyPositions() {
    for (const node of this.sim.nodes()) {
      if (!node.el) continue;
      node.el.style.left = `${node.x}px`;
      node.el.style.top = `${node.y}px`;
    }
  },

  _checkWinner() {
    const winnerId = this.el.getAttribute("data-winner-id");
    if (winnerId && !this._winnerApplied) {
      this._winnerApplied = true;
      pinWinner(this.sim, winnerId, CENTER_X, CENTER_Y);

      // Visual treatment for losers
      for (const node of this.sim.nodes()) {
        if (!node.el) continue;
        if (node.id === winnerId) continue;
        node.el.style.opacity = "0";
        node.el.style.transform = "translate(-50%, -50%) scale(0.95)";
      }
    }
  },
};

export default StageForce;
