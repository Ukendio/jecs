import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
    title: "Jecs",
    base: "/jecs/",
    description: "A VitePress Site",
    themeConfig: {
        // https://vitepress.dev/reference/default-theme-config
        nav: [
            { text: 'Home', link: '/' },
            { text: 'Examples', link: '/markdown-examples' },
            { text: 'API', link: '/api/jecs.md' }
        ],

        sidebar: {
            "/api/": [
                {
                    text: "API reference",
                    items: [
                        { text: "jecs", link: "/api/jecs" },
                        { text: "World", link: "/api/world" },
                        { text: "Query", link: "/api/query" }
                    ]
                }
            ],
            "/learn/": [
                {
                    text: "Introduction",
                    items: [
                        { text: 'Getting Started', link: '/overview/get-started' },
                        { text: 'First Jecs Project', link: '/overview/first-jecs-project' }
                    ]
                },
                {
                    text: 'Concepts',
                    items: [
                        { text: 'Entities', link: '/concepts/entities' },
                        { text: 'Static Components', link: '/concepts/static-components' },
                        { text: 'Queries', link: '/concepts/queries' },
                    ]
                },
                {
                    text: "FAQ",
                    items: [
                        { text: 'How can I contribute?', link: '/faq/contributing' }
                    ]
                },

            ],
            "/contributing/": [
                {
                    text: 'Contributing',
                    items: [
                        { text: 'Contribution Guidelines', link: '/contributing/guidelines' },
                        { text: 'Submitting Issues', link: '/contributing/issues' },
                        { text: 'Submitting Pull Requests', link: '/contributing/pull-requests' },
                    ]
                }
            ]
        },

        socialLinks: [
            { icon: 'github', link: 'https://github.com/vuejs/vitepress' }
        ]
    }
})
