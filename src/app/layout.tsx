import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "WebIngressos | Operação de eventos",
    template: "%s | WebIngressos",
  },
  description: "Operação e prestação de contas para eventos universitários.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt-BR" className="h-full antialiased">
      <body className="min-h-full">
        {children}
      </body>
    </html>
  );
}
