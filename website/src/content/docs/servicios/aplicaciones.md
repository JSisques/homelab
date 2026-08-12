---
title: Aplicaciones
description: Portfolio, Gardenia, Sisques Labs Landing y Days Off — las aplicaciones de cara al público del homelab.
---

Categoría `Applications` en `config/services.yaml`. A diferencia del resto de secciones, la mayoría de estas apps no tienen su código en este repositorio — aquí solo se documenta cómo se despliegan y exponen.

## Portfolio

<span class="slh-tier slh-tier--internal">interna</span> · `portfolio-web.home.arpa` · también `portfolio.jsisques.net`

Portfolio personal de desarrollador, sitio estático Astro con i18n es/en. El código fuente está en [github.com/JSisques/portfolio-web](https://github.com/JSisques/portfolio-web).

- El CI de ese repositorio, no este, construye y publica la imagen a `ghcr.io/jsisques/portfolio-web`; esta LXC solo hace `pull` y ejecuta la imagen publicada — nunca construye nada.
- Sin estado persistente ni secretos — redesplegar es solo traer la última etiqueta de imagen y reiniciar.
- Alcanzable en LAN (`https://portfolio-web.home.arpa`, vía Traefik) y públicamente (`https://portfolio.jsisques.net`, vía Cloudflare Tunnel).

Ver [rol de Ansible](https://github.com/JSisques/homelab/tree/main/ansible/roles/portfolio-web).

## Gardenia

<span class="slh-tier slh-tier--public">pública</span> · `gardenia.sisqueslabs.com`

Plataforma de gestión de huertos, desplegada en Kubernetes vía Argo CD. Su código vive en un repositorio propio, fuera de este.

Gardenia está pensada como la primera aplicación de nivel "aplicación" en Kubernetes, pero todavía no corre: espera a que el cluster tenga capacidad suficiente (ver [K3s](/homelab/servicios/infraestructura/#k3s)). Se documenta aquí como parte del catálogo y del roadmap, no como algo desplegado hoy.

## Sisques Labs Landing

<span class="slh-tier slh-tier--public">pública</span> · `landing.sisqueslabs.com`

Landing pública de Sisques Labs, sitio estático Astro. Código en [github.com/sisques-labs/sisques-labs-landing](https://github.com/sisques-labs). Desplegada en Kubernetes vía Argo CD (`kubernetes/applications/sisqueslabs-landing/`) — sin LXC ni ruta LAN por Traefik, expuesta únicamente a través del Cloudflare Tunnel mediante un `NodePort` en `k3s-server`. Al ser un sitio estático pequeño, corre sin problema en el nodo único de K3s, sin necesitar workers.

## Days Off

<span class="slh-tier slh-tier--public">pública</span> · `daysoff.sisqueslabs.com`

Calculadora de puentes/vacaciones, sitio estático Astro. Código en [github.com/sisques-labs/daysoff](https://github.com/sisques-labs). Mismo patrón de despliegue que Sisques Labs Landing: Kubernetes vía Argo CD (`kubernetes/applications/daysoff/`), sin LXC, expuesta solo por el Cloudflare Tunnel vía `NodePort`.

## Kafka

<span class="slh-tier slh-tier--internal">interna (planeado)</span> · `kafka.home.arpa`

Plataforma de streaming de eventos. Los manifiestos existen en `kubernetes/infrastructure/kafka/` (Strimzi), pero está **deliberadamente sin desplegar**: falta enganchar el operador Strimzi en la kustomization principal y el cluster de K3s necesita más capacidad de la que tiene un solo nodo — ver el comentario de cabecera en `kubernetes/argocd/applications/kafka.yaml`.

Cuando se despliegue: tres réplicas broker/controller, un `PersistentVolumeClaim` de 50 GiB por nodo sobre `local-path`, `deleteClaim: false`. Ver [recuperación ante desastres](/homelab/arquitectura/recuperacion-ante-desastres/#recuperación-de-kafka) para el procedimiento previsto.
