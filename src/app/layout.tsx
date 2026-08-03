import type { Metadata, Viewport } from "next"
import { Plus_Jakarta_Sans } from "next/font/google"

import "./globals.css"

const plusJakarta = Plus_Jakarta_Sans({
  subsets: ["latin", "latin-ext"],
  display: "swap",
  variable: "--font-plus-jakarta",
})

export const metadata: Metadata = {
  title: {
    default: "WebIngressos | Operação de eventos",
    template: "%s | WebIngressos",
  },
  description: "Operação e prestação de contas para eventos universitários.",
}

export const viewport: Viewport = {
  themeColor: "#0e6340",
  colorScheme: "light",
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="pt-BR" className={`${plusJakarta.variable} h-full antialiased`}>
      <body className="min-h-full">{children}</body>
    </html>
  )
}
