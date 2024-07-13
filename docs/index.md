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
      text: Get Started
      link: /overview/get-started.md
    - theme: alt
      text: API Examples
      link: /api.md

features:
  - title: Stupidly Fast
    icon: 🔥
    details: Iterates 500,000 entities at 60 frames per second.
  - title: Strictly Typed API
    icon: 🔒
    details: Has typings for both Luau and Typescript.
  - title: Zero-Dependencies
    icon: 📦
    details: Jecs doesn't rely on anything other than itself.
---