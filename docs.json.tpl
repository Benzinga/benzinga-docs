{
  "$schema": "https://mintlify.com/schema.json",
  "name": "Benzinga",
  "logo": {
    "dark": "/logo/dark.svg",
    "light": "/logo/light.svg"
  },
  "favicon": "/favicon.png",
  "colors": {
    "primary": "#8924A6",
    "light": "#ac6bd1",
    "dark": "#0D9373",
    "background": {
      "light": "#ffffff",
      "dark": "#0D1117"
    },
    "anchors": {
      "from": "#f6f1fa",
      "to": "#ac6bd1"
    }
  },
  "feedback": {
    "suggestEdit": true,
    "raiseIssue": true,
    "thumbsRating": true
  },
  "modeToggle": {
    "isHidden": false,
    "default": "light"
  },
  "analytics": {
    "ga4": {
      "measurementId": "G-S98KMZZZY1"
    }
  },
  "topbarLinks": [
    {
      "name": "Support",
      "url": "mailto:licensing@benzinga.com"
    }
  ],
  "topbarCtaButton": {
    "name": "Start for Free",
    "url": "https://www.benzinga.com/apis/licensing/register"
  },
  "api": {
    "auth": {
      "method": "key"
    },
    "playground": {
      "mode": "show"
    }
  },
  "tabs": [
    {
      "name": "Components",
      "url": "components"
    },
    {
      "name": "API Reference",
      "url": "api-reference"
    },
    {
      "name": "WebSocket Reference",
      "url": "ws-reference"
    },
    {
      "name": "SDKs",
      "url": "sdks"
    },
    {
      "name": "Changelog",
      "url": "changelog"
    }
  ],
  "navigation": [
    {
      "group": "Introduction",
      "pages": [
        "introduction/welcome",
        "introduction/introduction",
        "introduction/architecture",
        "introduction/faq"
      ]
    },
    {
      "group": "Services",
      "pages": [
        "services/overview"
      ]
    },
    {
      "group": "API Documentation",
      "pages": [
        "api-reference/introduction",
        "api-reference/authentication",
        "api-reference/errors",
        {{REPLACE_HERE}}
      ]
    },
    {
      "group": "WS Documentation",
      "pages": [
        "ws-reference/introduction",
        "ws-reference/authentication",
        "ws-reference/errors",
        {
          "group": "Data Websocket",
          "pages": [
            "ws-reference/data-websocket/get-analyst-insights-stream",
            "ws-reference/data-websocket/get-bulls-bears-say-stream",
            "ws-reference/data-websocket/get-calendar-earnings-stream",
            "ws-reference/data-websocket/get-calendar-ratings-stream",
            "ws-reference/data-websocket/get-consensus-ratings-stream"
          ]
        }
      ]
    }
  ],
  "footer": {
    "socials": {
      "twitter": "https://twitter.com/Benzinga",
      "facebook": "https://www.facebook.com/Benzinga/",
      "website": "https://www.benzinga.com/apis/",
      "github": "https://github.com/benzinga",
      "linkedin": "https://www.linkedin.com/company/benzinga/"
    },
    "links": [
      {
        "title": "POPULAR",
        "links": [
          { "label": "Benzinga", "url": "https://benzinga.com/" },
          { "label": "Benzinga Pro", "url": "https://benzinga.com/pro" },
          {
            "label": "Events",
            "url": "https://app.benzinga.com/share-secret"
          },
          { "label": "Pricing", "url": "https://benzinga.com/pricing" },
          {
            "label": "Blog",
            "url": "https://benzinga.com/blog"
          }
        ]
      },
      {
        "title": "USE CASES",
        "links": [
          {
            "label": "Calendar",
            "url": "https://benzinga.com/api-reference/calendar_api"
          },
          {
            "label": "Logos",
            "url": "https://benzinga.com/docs/integrations/platforms/kubernetes"
          },
          {
            "label": "WIIMS",
            "url": "https://benzinga.com/docs/documentation/platform/dynamic-secrets/overview"
          },
          {
            "label": "Quotes",
            "url": "https://benzinga.com/docs/integrations/frameworks/terraform"
          },
          {
            "label": "Fundamentals",
            "url": "https://benzinga.com/docs/integrations/platforms/ansible"
          },
          {
            "label": "Ticker Trends",
            "url": "https://benzinga.com/docs/integrations/cicd/jenkins"
          },
          {
            "label": "SDK",
            "url": "https://benzinga.com/docs/sdks/overview"
          }
        ]
      },
      {
        "title": "QUICK LINKS",
        "links": [
          {
            "label": "Changelog",
            "url": "https://docs.benzinga.com/changelog/overview"
          },
          {
            "label": "Feedback & Requests",
            "url": "https://github.com/Benzinga/benzinga/issues"
          },
          {
            "label": "FAQs",
            "url": "https://docs.benzinga.com/introduction/faq"
          }
        ]
      },
      {
        "title": "SUPPORT",
        "links": [
          {
            "label": "Support",
            "url": "https://benzinga.com/slack"
          },
          {
            "label": "Terms of Service",
            "url": "https://benzinga.com/terms"
          },
          {
            "label": "Privacy Policy",
            "url": "https://benzinga.com/privacy"
          }
        ]
      }
    ]
  }
}