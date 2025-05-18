---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "Jecs"
  tagline: Just a stupidly fast ECS
  image:
    src: /jecs_logo.svg
    alt: Jecs logo
  actions:
    - theme: brand
      text: Overview
      link: learn/overview.md
    - theme: alt
      text: API References
      link: /api/jecs.md

features:
  - title: Stupidly Fast
    icon: 🔥
    details: Iterates 800,000 entities at 60 frames per second.
  - title: Strictly Typed API
    icon: 🔒
    details: Has typings for both Luau and Typescript.
  - title: Zero-Dependencies
    icon: 📦
    details: Jecs doesn't rely on anything other than itself.
---
