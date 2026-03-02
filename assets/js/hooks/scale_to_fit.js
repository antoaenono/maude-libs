const ScaleToFit = {
  mounted() {
    this.inner = this.el.querySelector("[data-testid='virtual-canvas']")
    if (!this.inner) return

    this.virtualW = this.inner.offsetWidth
    this.virtualH = this.inner.offsetHeight

    this.observer = new ResizeObserver(() => this.rescale())
    this.observer.observe(this.el)
    this.rescale()
  },

  rescale() {
    if (!this.inner) return
    const containerW = this.el.clientWidth
    const containerH = this.el.clientHeight
    const scale = Math.min(containerW / this.virtualW, containerH / this.virtualH)
    const clamped = Math.max(scale, 0.5)
    this.el.style.setProperty("--canvas-scale", clamped)
  },

  destroyed() {
    if (this.observer) this.observer.disconnect()
  }
}

export default ScaleToFit
