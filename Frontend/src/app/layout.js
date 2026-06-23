import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import SessionTimeout from "./components/SessionTimeout";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata = {
  title: "NF-Bank",
  description: "Hệ thống Ngân hàng số NF-Bank",
};

export default function RootLayout({ children }) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">
        <SessionTimeout />
        {children}
      </body>
    </html>
  );
}
