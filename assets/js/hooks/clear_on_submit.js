const ClearOnSubmit = {
  mounted() {
    this.el.form.addEventListener("submit", () => {
      requestAnimationFrame(() => {
        this.el.value = "";
      });
      setTimeout(() => this.el.focus(), 50);
    });
  },
};

export default ClearOnSubmit;
