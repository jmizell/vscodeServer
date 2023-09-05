package main

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"html/template"
	"log"
	"math/big"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"time"

	"github.com/gorilla/sessions"
)

var (
	store = sessions.NewCookieStore(generateRandomKey(), generateRandomKey())
	users = map[string]string{
		os.Getenv("USER"): os.Getenv("PASS"),
	}
)

func main() {

	
	proxyTo, err := url.Parse("http://vscode:3000")
	if err != nil {
		log.Fatal(err)
	}

	proxy := httputil.NewSingleHostReverseProxy(proxyTo)
	proxy.ErrorLog = log.New(log.Writer(), "proxy: ", log.LstdFlags)
	proxy.ModifyResponse = logResponse

	cert, err := generateSelfSignedCert()
	if err != nil {
		log.Fatal(err)
	}

	// Create a new ServeMux
	mux := http.NewServeMux()

	// Add the login handlers
	mux.HandleFunc("/login", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			loginPageHandler(w, r)
		case http.MethodPost:
			loginHandler(w, r)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/logout", logoutHandler)

	// Wrap the proxy handler with our middleware
	authProxy := authMiddleware(logRequest(proxy))

	// Use a wildcard pattern to match all other requests
	mux.Handle("/", authProxy)

	server := &http.Server{
		Addr:    ":3001",
		Handler: mux,
		TLSConfig: &tls.Config{
			// Prefer curves which we have assembly implementations for
			CurvePreferences: []tls.CurveID{
				tls.X25519, // This one is for TLS 1.3
				tls.CurveP256,
			},
			// Only use TLS 1.3 ciphersuites
			CipherSuites: []uint16{
				tls.TLS_AES_128_GCM_SHA256,
				tls.TLS_AES_256_GCM_SHA384,
				tls.TLS_CHACHA20_POLY1305_SHA256,
				tls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
			},
			MinVersion:               tls.VersionTLS13, // Enforce TLS 1.3 only
			PreferServerCipherSuites: true,             // Enforce the server's order of ciphers
			Certificates:             []tls.Certificate{cert},
		},
	}

	log.Fatal(server.ListenAndServeTLS("", ""))
}

func generateSelfSignedCert() (tls.Certificate, error) {
	priv, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return tls.Certificate{}, err
	}

	// Maximum possible value a 20-octet (160 bit) integer can hold
	// This is the maximum allowed serial number in a certificate as per RFC 5280
	max := new(big.Int)
	max.Exp(big.NewInt(2), big.NewInt(160), nil).Sub(max, big.NewInt(1))

	serialNumber, err := rand.Int(rand.Reader, max)
	if err != nil {
		return tls.Certificate{}, err
	}

	template := x509.Certificate{
		SerialNumber: serialNumber,
		Subject: pkix.Name{
			Organization: []string{"Your Organization"},
		},
		IPAddresses: []net.IP{net.ParseIP("127.0.0.1")},
		NotBefore:   time.Now(),
		NotAfter:    time.Now().Add(time.Hour * 24 * 365),

		KeyUsage:              x509.KeyUsageKeyEncipherment | x509.KeyUsageDigitalSignature,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		BasicConstraintsValid: true,
	}

	certBytes, err := x509.CreateCertificate(rand.Reader, &template, &template, &priv.PublicKey, priv)
	if err != nil {
		return tls.Certificate{}, err
	}

	certPEM := pem.EncodeToMemory(&pem.Block{
		Type:  "CERTIFICATE",
		Bytes: certBytes,
	})

	privBytes, err := x509.MarshalPKCS8PrivateKey(priv)
	if err != nil {
		return tls.Certificate{}, err
	}

	privPEM := pem.EncodeToMemory(&pem.Block{
		Type:  "PRIVATE KEY",
		Bytes: privBytes,
	})

	cert, err := tls.X509KeyPair(certPEM, privPEM)
	if err != nil {
		return tls.Certificate{}, err
	}

	return cert, nil
}

// logRequest is a middleware that logs http requests
func logRequest(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s %s\n", r.RemoteAddr, r.Method, r.URL)
		next.ServeHTTP(w, r)
	})
}

// logResponse is a function that logs http responses
func logResponse(r *http.Response) error {
	log.Printf("%s %s\n", r.Request.RemoteAddr, r.Status)
	return nil
}

func authMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		session, _ := store.Get(r, "session")

		if auth, ok := session.Values["authenticated"].(bool); !ok || !auth {
			// Save the original URL
			session.Values["originalURL"] = r.URL.RequestURI()
			session.Save(r, w)

			http.Redirect(w, r, "/login", http.StatusSeeOther)
			return
		}

		next.ServeHTTP(w, r)
	})
}

const loginPage = `
<!DOCTYPE html>
<html>
	<head>
		<style>
			body {
				background-color: black;
				display: flex;
				justify-content: center;
				align-items: center;
				height: 100vh;
				margin: 0;
			}

			form {
				background-color: white;
				padding: 20px;
				border-radius: 15px;
			}

			label, input {
				display: block;
				margin-bottom: 10px;
			}

			input[type="submit"] {
				background-color: black;
				color: white;
				border: none;
				padding: 10px 20px;
				border-radius: 5px;
				cursor: pointer;
			}

			input[type="submit"]:hover {
				background-color: #555;
			}
		</style>
	</head>
	<body>
		<form action="/login" method="post">
			<label for="username">Username:</label>
			<input type="text" id="username" name="username">
			<label for="password">Password:</label>
			<input type="password" id="password" name="password">
			<input type="submit" value="Submit">
		</form>
	</body>
</html>
`

func loginPageHandler(w http.ResponseWriter, r *http.Request) {
	tmpl := template.Must(template.New("").Parse(loginPage))
	tmpl.Execute(w, nil)
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
	session, _ := store.Get(r, "session")

	r.ParseForm()
	username := r.Form.Get("username")
	password := r.Form.Get("password")

	// Check if the username and password are correct
	if users[username] == password {
		// Set user as authenticated
		session.Values["authenticated"] = true

		// Get the original URL and validate it
		originalURL, ok := session.Values["originalURL"].(string)
		if !ok || !isRelativeURL(originalURL) {
			originalURL = "/" // Default URL
		}

		session.Save(r, w)
		http.Redirect(w, r, originalURL, http.StatusSeeOther)
	} else {
		// Show the login page again
		http.Redirect(w, r, "/login", http.StatusSeeOther)
	}
}

func logoutHandler(w http.ResponseWriter, r *http.Request) {
	session, _ := store.Get(r, "session")

	// Revoke users authentication
	session.Values["authenticated"] = false
	session.Save(r, w)

	http.Redirect(w, r, "/login", http.StatusSeeOther)
}

func isRelativeURL(s string) bool {
	u, err := url.Parse(s)
	return err == nil && u.Scheme == "" && u.Host == ""
}

func generateRandomKey() []byte {
	key := make([]byte, 32)
	_, err := rand.Read(key)
	if err != nil {
		log.Fatal("failed to generate random key:", err)
	}
	return key
}
