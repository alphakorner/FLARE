# FLARE — PWA prototype

Interface responsive en français, carte Leaflet/OpenStreetMap, navigation mobile, signalements locaux, fil chronologique, repères de premiers secours, export et effacement local, mode discret et service worker.

## Lancer
- Décompresser le ZIP.
- Servir le dossier avec un serveur HTTP local, par exemple `python -m http.server 8080`.
- Ouvrir `http://localhost:8080`. La géolocalisation et l'installation PWA exigent généralement HTTPS ou localhost.
- Une connexion internet est requise pour charger Leaflet depuis le CDN et les tuiles OSM la première fois.

## État réel
**Prototype front-end uniquement.** Pas de projet Supabase connecté, pas d'API Claude connectée, pas de push, pas de réseau medic/SOS réel, pas de consensus serveur, pas de flux CTS/trafic en direct, pas de heatmap de population. Les signalements ajoutés sont conservés localement dans le navigateur. Les points de la carte sont des exemples fictifs. Le mode discret n'efface pas l'historique du navigateur et n'est pas un mécanisme de sécurité.

## Mise en production
1. Créer un projet Supabase et examiner `supabase-schema.sql`.
2. Concevoir une authentification anonyme robuste et des Edge Functions/RPC pour toutes les écritures, le consensus spatial, le TTL et les limites de débit. Ne pas utiliser de politiques RLS publiques permissives.
3. Pour PIN, ne jamais stocker le code brut ni un hash rapide sans protection contre le brute-force ; prévoir une récupération sécurisée.
4. Connecter Claude via une Edge Function avec secret côté serveur, données agrégées minimales et sortie JSON validée.
5. Ajouter sources officielles vérifiées pour transports/alertes, et documenter leur fraîcheur.
6. Tester la charge et la résilience : 400 000 personnes exige une architecture de production, des limites de débit, des files d'événements et un test de charge indépendant.
7. Respecter la politique de tuiles OpenStreetMap. Le service public OSM n'est pas un CDN à précharger massivement ; ne pas aspirer 10 000 tuiles. Choisir un fournisseur adapté si la charge augmente.
8. Faire auditer sécurité, confidentialité, accessibilité et conseils médicaux/juridiques avant tout usage réel.
