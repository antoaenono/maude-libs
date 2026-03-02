const ScaleToFit = {
  mounted() {
    this.inner = this.el.querySelector("[data-testid='virtual-canvas']")
    if (!this.inner) return

    this.observer = new ResizeObserver(() => this.rescale())
    this.observer.observe(this.el)
    this.rescale()
  },

  updated() {
    // LiveView DOM patches overwrite the inner element's style attribute,
    // wiping out the transform we set. Re-apply after every patch.
    this.rescale()
  },

  rescale() {
    if (!this.inner) return
    const containerW = this.el.clientWidth
    const containerH = this.el.clientHeight
    const virtualW = this.inner.offsetWidth
    const virtualH = this.inner.offsetHeight
    const scale = Math.min(containerW / virtualW, containerH / virtualH)
    const clamped = Math.max(scale, 0.5)

    const offsetX = (containerW - virtualW * clamped) / 2
    const offsetY = (containerH - virtualH * clamped) / 2

    this.inner.style.transform = `translate(${offsetX}px, ${offsetY}px) scale(${clamped})`
    this.inner.style.transformOrigin = "0 0"
  },

  destroyed() {
    if (this.observer) this.observer.disconnect()
  }
}

export default ScaleToFit
