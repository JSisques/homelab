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
      customCss: ["./src/styles/custom.css"],
      sidebar: [
        {
          label: "Guías",
          items: [
            { label: "Cómo funciona (flujo de datos)", slug: "guides/flujo-de-datos" },
            { label: "Cómo desplegarlo", slug: "guides/desplegar" },
          ],
        },
        {
          label: "Arquitectura",
          items: [
            { label: "Visión general", slug: "arquitectura/vision-general" },
            { label: "Almacenamiento", slug: "arquitectura/almacenamiento" },
            { label: "Recuperación ante desastres", slug: "arquitectura/recuperacion-ante-desastres" },
          ],
        },
        {
          label: "Configuración",
          items: [{ label: "Modelo de configuración", slug: "configuracion/modelo" }],
        },
        {
          label: "Servicios",
          items: [
            { label: "Catálogo", slug: "servicios/catalogo" },
            { label: "Monitorización y observabilidad", slug: "servicios/monitorizacion" },
            { label: "Redes y acceso", slug: "servicios/redes" },
            { label: "Multimedia y descargas", slug: "servicios/multimedia-descargas" },
            { label: "Productividad y automatización", slug: "servicios/productividad-automatizacion" },
            { label: "Aplicaciones", slug: "servicios/aplicaciones" },
            { label: "Infraestructura", slug: "servicios/infraestructura" },
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
