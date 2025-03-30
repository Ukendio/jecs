import { defineConfig } from "vitepress";

// https://vitepress.dev/reference/site-config
export default defineConfig({
	title: "Jecs",
	base: "/jecs/",
	description: "A VitePress Site",
	themeConfig: {
		// https://vitepress.dev/reference/default-theme-config
		nav: [
			{ text: "Learn", link: "/" },
			{ text: "API", link: "/api/jecs.md" },
			{ text: "Examples", link: "https://github.com/Ukendio/jecs/tree/main/examples" },
			{ text: "Coverage", link: "/coverage/index.html" },
		],

		sidebar: {
			"/api/": [
				{
					text: "API reference",
					items: [
						{ text: "jecs", link: "/api/jecs" },
						{ text: "World", link: "/api/world" },
						{ text: "Query", link: "/api/query" },
					],
				},
			],
			"/learn/": [
				{
					text: "Introduction",
					items: [
						{ text: "Getting Started", link: "/learn/overview/get-started" },
						{ text: "First Jecs Project", link: "/learn/overview/first-jecs-project" },
					],
				},
				{
					text: "Concepts",
					items: [
						{ text: "Entities and Components", link: "/learn/concepts/entities-and-components" },
						{ text: "Queries", link: "/learn/concepts/queries" },
						{ text: "Relationships", link: "/learn/concepts/relationships" },
						{ text: "Component Traits", link: "learn/concepts/component-traits" },
						{ text: "Addons", link: "/learn/concepts/addons" },
					],
				},
				{
					text: "FAQ",
					items: [{ text: "How can I contribute?", link: "/learn/faq/contributing" }],
				},
			],
			"/contributing/": [
				{
					text: "Contributing",
					items: [
						{ text: "Contribution Guidelines", link: "/learn/contributing/guidelines" },
						{ text: "Submitting Issues", link: "/learn/contributing/issues" },
						{ text: "Submitting Pull Requests", link: "/learn/contributing/pull-requests" },
					],
				},
			],
		},

		socialLinks: [{ icon: "github", link: "https://github.com/ukendio/jecs" }],
	},
});
