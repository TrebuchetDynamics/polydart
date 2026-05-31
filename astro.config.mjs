import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  integrations: [
    starlight({
      title: 'Polydart',
      description:
        'Dart-native Polymarket SDK documentation for Flutter and Dart applications.',
      sidebar: [
        {
          label: 'Start',
          items: [{ label: 'Overview', link: '/' }],
        },
        {
          label: 'Flutter',
          items: [{ label: 'Quickstart', slug: 'flutter/quickstart' }],
        },
        {
          label: 'Protocol Safety',
          items: [
            {
              label: 'Wallet-Mediated Signing',
              slug: 'protocol-safety/wallet-signing',
            },
            {
              label: 'Enable Trading Planning',
              slug: 'protocol-safety/enable-trading',
            },
            {
              label: 'Live Safety Gates',
              slug: 'protocol-safety/live-safety-gates',
            },
            {
              label: 'Credential Boundaries',
              slug: 'protocol-safety/credential-boundaries',
            },
          ],
        },
        {
          label: 'API Guides',
          items: [
            {
              label: 'Read-Only Market Data',
              slug: 'api/read-only-market-data',
            },
            { label: 'Paper Mode', slug: 'api/paper-mode' },
          ],
        },
        {
          label: 'Fidelity',
          items: [
            { label: 'Polygolem Fidelity', slug: 'fidelity/polygolem' },
          ],
        },
        {
          label: 'Reference',
          items: [{ label: 'API Module Map', slug: 'reference/api-module-map' }],
        },
      ],
      tableOfContents: { minHeadingLevel: 2, maxHeadingLevel: 3 },
      editLink: {
        baseUrl: 'https://github.com/TrebuchetDynamics/polydart/edit/main/',
      },
      lastUpdated: true,
      pagefind: true,
    }),
  ],
});
