import { defineConfig } from "vitepress";

// https://vitepress.dev/reference/site-config
export default defineConfig({
	title: "Jecs",
	base: "/jecs/",
	description: "A VitePress Site",
	themeConfig: {
		// https://vitepress.dev/reference/default-theme-config
		nav: [
			{ text: "Learn", link: "/learn/overview.md" },
			{ text: "API", link: "/api/jecs.md" },
			{ text: "Resources", link: "/resources" },
		],

		sidebar: {
			"/api/": [
				{
					text: "Namespaces",
					items: [
						{ text: "jecs", link: "/api/jecs" },
						{ text: "World", link: "/api/world" },
						{ text: "Query", link: "/api/query" },
					],
				},
			],
			"/learn/": [
				{
					text: "Overview",
					items: [{ text: "Overview", link: "/learn/overview" }],
				},
				{
					text: "API Reference",
					items: [
						{ text: "jecs", link: "/api/jecs" },
						{ text: "World", link: "/api/world" },
						{ text: "Query", link: "/api/query" },
					],
				},
				{
					text: "Contributing",
					items: [
						{ text: "Contribution Guidelines", link: "/learn/contributing/guidelines" },
						{ text: "Submitting Issues", link: "/learn/contributing/issues" },
						{ text: "Submitting Pull Requests", link: "/learn/contributing/pull-requests" },
						{ text: "Code Coverage", link: "/learn/contributing/coverage" },
					],
				},
			],
		},

		socialLinks: [{ icon: "github", link: "https://github.com/ukendio/jecs" }],
	},
});
