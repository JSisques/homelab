// @ts-check
import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";

// https://astro.build/config
export default defineConfig({
  site: "https://jsisques.github.io",
  base: "/homelab",
  integrations: [
    starlight({
      title: "Homelab",
      description: "Documentación del homelab as code de jsisques.",
      social: [
        {
          icon: "github",
          label: "GitHub",
          href: "https://github.com/JSisques/homelab",
        },
      ],
      sidebar: [
        {
          label: "Guías",
          items: [
            { label: "Cómo funciona (flujo de datos)", slug: "guides/flujo-de-datos" },
            { label: "Cómo desplegarlo", slug: "guides/desplegar" },
          ],
        },
        {
          label: "Referencia",
          items: [{ autogenerate: { directory: "reference" } }],
        },
      ],
    }),
  ],
});
