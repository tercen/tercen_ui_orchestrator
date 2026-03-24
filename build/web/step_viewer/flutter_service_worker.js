'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"index.html": "834b342b93dc2c5168be88b91eb2a94a",
"/": "834b342b93dc2c5168be88b91eb2a94a",
"test_debug.html": "6905f4162482e14b5e4828fa37ef485b",
"flutter_bootstrap.js": "c3bf5251158d0c48cd8c4f19cf0fdcb7",
"version.json": "309a5f26d3eb03d39dbf92fb7eb2c23a",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"test_streaming.html": "9a1391141032342db99e5eef607cad6b",
"ggrs/interaction_manager.js": "310b51bc96eaef06ad9d43579797087d",
"ggrs/plot_state.js": "5c1929953a1017f020a54f7c2d6db4cc",
"ggrs/render_coordinator.js": "26eb8e5f5c9f65c533b97ca26b43f2fc",
"ggrs/ggrs_gpu.js": "e824f36e5ec5163381dca1e6a3829ce5",
"ggrs/ggrs_gpu_v3.js": "0091f797bae5d788d66f2bd21ac730ef",
"ggrs/interaction_manager.js.bak": "bd12d663d82246896b8a2726d626eb44",
"ggrs/bootstrap_v2.js": "e275f6b423fefdb44aedfd1831e3f555",
"ggrs/bootstrap.js.bak": "46d073153cdf29fc53ef0706c13b637b",
"ggrs/ggrs_gpu_v2.js.bak": "40e3cc27569152510f1fe06fe40a9b27",
"ggrs/plot_orchestrator.js": "32ce4e01493933a4acefa057b6413aa9",
"ggrs/mock_data_worker.js": "e0cd8aa69639f902f705c5d9a34d48ca",
"ggrs/ggrs_gpu.js.bak": "f7fd7f4ed0835a366589e9dfe4d92715",
"ggrs/bootstrap_v2.js.bak": "9d4ff38c0adab1f0232b78b300eb65b3",
"ggrs/bootstrap.js": "8b91aa5075faf876f25d97ceca5b8948",
"ggrs/ggrs_gpu_v3.js.bak": "1701c3ad3cbf73545c43957353a97e83",
"ggrs/bootstrap_v3.js.bak": "72af4d92205574ec0333f81c939dd588",
"ggrs/viewport_state.js": "8acb9aedb6fa055234e57ad619c2b251",
"ggrs/bootstrap_v3.js": "0e99bb4faac573cf402ee70c4500b1b5",
"ggrs/pkg/package.json": "8666197d23c2e64f6bca29b1f47f3779",
"ggrs/pkg/ggrs_wasm.js": "2b3abe21b2e895c271e9899af90fe9a1",
"ggrs/pkg/ggrs_wasm.d.ts": "11125d05e8f712e1ca69fc77111e594b",
"ggrs/pkg/ggrs_wasm_bg.wasm": "537cc8131632f6cb6b487c41ee89e688",
"ggrs/pkg/ggrs_wasm_bg.wasm.d.ts": "1043fa005b73336176349baca157baa2",
"ggrs/ggrs_gpu_v2.js": "693f4b2eb56fbb52b89b13055a726e65",
"test_coordinator.html": "0ff5d6c12fbc58e4c0ca5d5cb46c391f",
"test_simple.html": "f2ebef3730cd85ace97a1f06512b2638",
"test_chrome.html": "03cad5776f066b344cafc813ceeeb7d7",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"test_v3_render.html": "8853675222f5d23c97d323e370471ef8",
"main.dart.js": "c10e41214eb3f121cea01359bdd0079f",
"assets/NOTICES": "cb7180c0bd512c3683b10353abef06fd",
"assets/AssetManifest.bin": "d07a484f96dc04efe00fb7dc5dae99d5",
"assets/AssetManifest.bin.json": "94770df6ee426825ac5e16b2687ed5b6",
"assets/AssetManifest.json": "ea66be726abc225e92ac802d1f12856a",
"assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf": "6a9173365c18d9597b8afb84b1065051",
"assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf": "1fcba7a59e49001aa1b4409a25d425b0",
"assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Regular-400.otf": "b2703f18eee8303425a5342dba6958db",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/FontManifest.json": "2a3f09429db12146b660976774660777",
"assets/fonts/MaterialIcons-Regular.otf": "699f33287223cbff107f42cb405db267",
"test_interaction.html": "bf814c93d958fc43ae999a422aa4d982"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
