/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      backgroundImage: {
        'hero': "url('/src/assets/hero.png')",
        'minted': "url('/src/assets/mintBackground.gif')",
      },
      gridTemplateColumns: {
        'grid-col-auto-fill': 'repeat(3, minmax(1rem, 1fr))',
      },
    },
  },
  plugins: [
  ],
}
