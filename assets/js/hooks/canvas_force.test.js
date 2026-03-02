import { describe, it, expect } from "vitest";
import {
  forceSimulation,
  forceManyBody,
  forceCollide,
} from "d3-force";

function runToCompletion(sim) {
  // Tick until simulation cools down (alpha < alphaMin)
  while (sim.alpha() > sim.alphaMin()) {
    sim.tick();
  }
}

describe("canvas force simulation", () => {
  it("keeps a single node away from the center plus button", () => {
    const centerNode = { id: "__center__", fx: 0, fy: 0, size: 24, fixed: true };
    const regularNode = { id: "node-1", size: 48, x: 80, y: 0, vx: 0, vy: 0 };

    const sim = forceSimulation()
      .force("charge", forceManyBody().strength(-300))
      .force("collide", forceCollide((d) => d.size + 6).strength(1))
      .alphaDecay(0.02)
      .nodes([centerNode, regularNode]);

    runToCompletion(sim);

    const dist = Math.sqrt(regularNode.x ** 2 + regularNode.y ** 2);
    const minSeparation = centerNode.size + 6 + regularNode.size + 6; // 84px

    expect(dist).toBeGreaterThanOrEqual(minSeparation);
  });
});
