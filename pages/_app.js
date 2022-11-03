import Script from 'next/script';

import { ThemeProvider } from 'next-themes';

import { Footer, Navbar } from '../components';

import '../styles/globals.css';

const MyApp = ({ Component, pageProps }) => (

  <ThemeProvider attribute="class">

    <div className="dark:bg-nft-dark bg-white min-h-screen">
      <Navbar />
      <Component {...pageProps} />
      <Footer />
    </div>
    <Script src="https://kit.fontawesome.com/364b062ad2.js" crossorigin="anonymous"> </Script>
  </ThemeProvider>
);

export default MyApp;
