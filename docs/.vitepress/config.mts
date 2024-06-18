import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "JECS",
  description: "Just another ECS",
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    logo: '/logo_old.png',

    search: { provider: 'local' },

    nav: [
      { text: 'Home', link: '/' },
      { text: 'Learn', link: '/learn' },
      { text: 'Reference', link: '/reference' }
    ],

    sidebar: {
      '/learn/': [
        {
          text: 'Learn',
          items: [
            {text: 'Getting Started', link: '/learn'},
            {text: 'Why ECS?', link: '/learn/coming-soon.md'},
            {
              text: 'Guides', link: '/learn/guides.md', items: [
                { text: 'Entities, Components, Systems', link: '/learn/learn-ecs' },
                { text: 'Systems Continued', link: '/learn/your-first-system'},
                { text: 'Scheduling Systems', link: '/learn/scheduling-systems' },
                { text: 'Querying Components', link: '/learn/coming-soon' },
                { text: 'Querying Pairs', link: '/learn/coming-soon' },
              ]
            },
            // {
            //   text: 'Advanced Guides', link: '/learn/coming-soon', items: [
            //     {text: 'Scheduling Systems', link: '/learn/coming-soon'},
            //     {text: 'Using a Context Entity', link: '/learn/coming-soon'},
            //     {text: 'Listening to Changes', link: '/learn/coming-soon'},
            //     {text: 'Collecting Events', link: '/learn/coming-soon'},
            //   ]
            // },
            {text: 'Best Practices', link: '/learn/coming-soon'},
            {text: 'Contributions', link: '/learn/coming-soon'},
          ]
        }
      ],
      '/reference/': [
        {
          text: 'Reference',
          items: [
            { text: 'JECS', link: '/reference', items: [
                { text: 'World', link: '/reference' },
                { text: 'QueryIter', link: '/reference/query' },
              ] },
          ]
        }
      ],
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/Ukendio/jecs' }
    ]
  }
})