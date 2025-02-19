import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
    title: "Jecs",
    base: "/jecs/",
    description: "Just a stupidly fast Entity Component System",
    themeConfig: {
        // https://vitepress.dev/reference/default-theme-config
        nav: [
            { text: 'Learn', link: '/' },
            { text: 'API', link: '/api/jecs.md' },
            { text: 'Examples', link: 'https://github.com/Ukendio/jecs/tree/main/examples' },
        ],

        sidebar: {
            "/api/": [
                {
                    text: "API Reference",
                    items: [
                        { text: 'Jecs', link: '/api/jecs' },
                        { text: 'World', link: '/api/world' },
                        { text: 'Query', link: '/api/query' }
                    ]
                }
            ],
            "/learn/": [
                {
                    text: "Introduction",
                    items: [
                        { text: 'Getting Started', link: '/learn/overview/get-started' },
                        { text: 'First Jecs Project', link: '/learn/overview/first-jecs-project' }
                    ]
                },
                {
                    text: 'Concepts',
                    items: [
                        { text: 'Entities and Components', link: '/learn/concepts/entities-and-components' },
                        { text: 'Queries', link: '/learn/concepts/queries' },
                        { text: 'Relationships', link: '/learn/concepts/relationships' },
                        { text: 'Component Traits', link: '/learn/concepts/component-traits' },
                        { text: 'Addons', link: '/learn/concepts/addons' }
                    ]
                },
                {
                    text: "FAQ",
                    items: [
                        { text: 'Common Issues', link: '/learn/faq/common-issues' },
                        { text: 'Migrating from Matter', link: '/learn/faq/migrating-from-matter' },
                        { text: 'Contributing', link: '/learn/faq/contributing' }
                    ]
                }
            ],
            "/contributing/": [
                {
                    text: 'Contributing',
                    items: [
                        { text: 'Guidelines', link: '/contributing/guidelines' },
                        { text: 'Submitting Issues', link: '/contributing/issues' },
                        { text: 'Pull Requests', link: '/contributing/pull-requests' }
                    ]
                }
            ]
        },

        socialLinks: [
            { icon: 'github', link: 'https://github.com/ukendio/jecs' },
            { icon: 'discord', link: 'https://discord.gg/h2NV8PqhAD' }
        ],

        search: {
            provider: 'local',
            options: {
                detailedView: true
            }
        }
    }
})
