import daisyui from "daisyui";
import { fontFamily } from "tailwindcss/defaultTheme";

module.exports = {
  content: ["./index.html", "./src/**/*.{gleam,mjs}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Kanit', ...fontFamily.sans]
      }
    },
  },
  plugins: [daisyui],
  daisyui: {
    themes: ["dark"]
  },
};
