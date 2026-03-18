'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"index.html": "985bd51ced61cef48296f93a524701a6",
"/": "985bd51ced61cef48296f93a524701a6",
"flutter_bootstrap.js": "f1e57868d95a4eb8ddee9b1753070182",
"version.json": "7117ace3c5a191b91533e394d8df6fe3",
"step_viewer/index.html": "834b342b93dc2c5168be88b91eb2a94a",
"step_viewer/test_debug.html": "6905f4162482e14b5e4828fa37ef485b",
"step_viewer/flutter_bootstrap.js": "c3bf5251158d0c48cd8c4f19cf0fdcb7",
"step_viewer/version.json": "309a5f26d3eb03d39dbf92fb7eb2c23a",
"step_viewer/canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"step_viewer/canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"step_viewer/canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"step_viewer/canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"step_viewer/canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"step_viewer/canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"step_viewer/canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"step_viewer/canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"step_viewer/canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"step_viewer/canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"step_viewer/canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"step_viewer/canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"step_viewer/test_streaming.html": "9a1391141032342db99e5eef607cad6b",
"step_viewer/ggrs/interaction_manager.js": "310b51bc96eaef06ad9d43579797087d",
"step_viewer/ggrs/plot_state.js": "5c1929953a1017f020a54f7c2d6db4cc",
"step_viewer/ggrs/render_coordinator.js": "26eb8e5f5c9f65c533b97ca26b43f2fc",
"step_viewer/ggrs/ggrs_gpu.js": "e824f36e5ec5163381dca1e6a3829ce5",
"step_viewer/ggrs/ggrs_gpu_v3.js": "0091f797bae5d788d66f2bd21ac730ef",
"step_viewer/ggrs/interaction_manager.js.bak": "bd12d663d82246896b8a2726d626eb44",
"step_viewer/ggrs/bootstrap_v2.js": "e275f6b423fefdb44aedfd1831e3f555",
"step_viewer/ggrs/bootstrap.js.bak": "46d073153cdf29fc53ef0706c13b637b",
"step_viewer/ggrs/ggrs_gpu_v2.js.bak": "40e3cc27569152510f1fe06fe40a9b27",
"step_viewer/ggrs/plot_orchestrator.js": "32ce4e01493933a4acefa057b6413aa9",
"step_viewer/ggrs/mock_data_worker.js": "e0cd8aa69639f902f705c5d9a34d48ca",
"step_viewer/ggrs/ggrs_gpu.js.bak": "f7fd7f4ed0835a366589e9dfe4d92715",
"step_viewer/ggrs/bootstrap_v2.js.bak": "9d4ff38c0adab1f0232b78b300eb65b3",
"step_viewer/ggrs/bootstrap.js": "8b91aa5075faf876f25d97ceca5b8948",
"step_viewer/ggrs/ggrs_gpu_v3.js.bak": "1701c3ad3cbf73545c43957353a97e83",
"step_viewer/ggrs/bootstrap_v3.js.bak": "72af4d92205574ec0333f81c939dd588",
"step_viewer/ggrs/viewport_state.js": "8acb9aedb6fa055234e57ad619c2b251",
"step_viewer/ggrs/bootstrap_v3.js": "0e99bb4faac573cf402ee70c4500b1b5",
"step_viewer/ggrs/pkg/package.json": "8666197d23c2e64f6bca29b1f47f3779",
"step_viewer/ggrs/pkg/ggrs_wasm.js": "2b3abe21b2e895c271e9899af90fe9a1",
"step_viewer/ggrs/pkg/ggrs_wasm.d.ts": "11125d05e8f712e1ca69fc77111e594b",
"step_viewer/ggrs/pkg/ggrs_wasm_bg.wasm": "537cc8131632f6cb6b487c41ee89e688",
"step_viewer/ggrs/pkg/ggrs_wasm_bg.wasm.d.ts": "1043fa005b73336176349baca157baa2",
"step_viewer/ggrs/ggrs_gpu_v2.js": "693f4b2eb56fbb52b89b13055a726e65",
"step_viewer/test_coordinator.html": "0ff5d6c12fbc58e4c0ca5d5cb46c391f",
"step_viewer/test_simple.html": "f2ebef3730cd85ace97a1f06512b2638",
"step_viewer/test_chrome.html": "03cad5776f066b344cafc813ceeeb7d7",
"step_viewer/flutter.js": "888483df48293866f9f41d3d9274a779",
"step_viewer/test_v3_render.html": "8853675222f5d23c97d323e370471ef8",
"step_viewer/main.dart.js": "c10e41214eb3f121cea01359bdd0079f",
"step_viewer/assets/NOTICES": "cb7180c0bd512c3683b10353abef06fd",
"step_viewer/assets/AssetManifest.bin": "d07a484f96dc04efe00fb7dc5dae99d5",
"step_viewer/assets/AssetManifest.bin.json": "94770df6ee426825ac5e16b2687ed5b6",
"step_viewer/assets/AssetManifest.json": "ea66be726abc225e92ac802d1f12856a",
"step_viewer/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf": "6a9173365c18d9597b8afb84b1065051",
"step_viewer/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf": "1fcba7a59e49001aa1b4409a25d425b0",
"step_viewer/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Regular-400.otf": "b2703f18eee8303425a5342dba6958db",
"step_viewer/assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"step_viewer/assets/FontManifest.json": "2a3f09429db12146b660976774660777",
"step_viewer/assets/fonts/MaterialIcons-Regular.otf": "699f33287223cbff107f42cb405db267",
"step_viewer/test_interaction.html": "bf814c93d958fc43ae999a422aa4d982",
"manifest.json": "06d92a213d8d2241c20d10593ce31349",
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
"factor_nav/index.html": "73355a605d22b45f56e43fcae3b115ad",
"factor_nav/flutter_bootstrap.js": "8688c3e6ffe396682504da6187b0e701",
"factor_nav/version.json": "a95218349282dff1cb154a9541c63f2c",
"factor_nav/canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"factor_nav/canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"factor_nav/canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"factor_nav/canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"factor_nav/canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"factor_nav/canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"factor_nav/canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"factor_nav/canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"factor_nav/canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"factor_nav/canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"factor_nav/canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"factor_nav/canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"factor_nav/flutter.js": "888483df48293866f9f41d3d9274a779",
"factor_nav/main.dart.js": "610db8a557add52dd36e7fa810e62968",
"factor_nav/assets/NOTICES": "cb7180c0bd512c3683b10353abef06fd",
"factor_nav/assets/AssetManifest.bin": "d07a484f96dc04efe00fb7dc5dae99d5",
"factor_nav/assets/AssetManifest.bin.json": "94770df6ee426825ac5e16b2687ed5b6",
"factor_nav/assets/AssetManifest.json": "ea66be726abc225e92ac802d1f12856a",
"factor_nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf": "6a9173365c18d9597b8afb84b1065051",
"factor_nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf": "ad72f00c2e15fe9de0e809de8ee2f32e",
"factor_nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Regular-400.otf": "b2703f18eee8303425a5342dba6958db",
"factor_nav/assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"factor_nav/assets/FontManifest.json": "2a3f09429db12146b660976774660777",
"factor_nav/assets/fonts/MaterialIcons-Regular.otf": "776e5bea0c81709b3adc2cb7debf5396",
"factor-nav/index.html": "73355a605d22b45f56e43fcae3b115ad",
"factor-nav/flutter_bootstrap.js": "7056879e5a03d5c84717902a4687ce2c",
"factor-nav/version.json": "a95218349282dff1cb154a9541c63f2c",
"factor-nav/canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"factor-nav/canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"factor-nav/canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"factor-nav/canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"factor-nav/canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"factor-nav/canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"factor-nav/canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"factor-nav/canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"factor-nav/canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"factor-nav/canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"factor-nav/canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"factor-nav/canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"factor-nav/flutter.js": "888483df48293866f9f41d3d9274a779",
"factor-nav/main.dart.js": "0963e83a3e77bf4e637bfe1b769d08d4",
"factor-nav/assets/NOTICES": "cb7180c0bd512c3683b10353abef06fd",
"factor-nav/assets/AssetManifest.bin": "d07a484f96dc04efe00fb7dc5dae99d5",
"factor-nav/assets/AssetManifest.bin.json": "94770df6ee426825ac5e16b2687ed5b6",
"factor-nav/assets/AssetManifest.json": "ea66be726abc225e92ac802d1f12856a",
"factor-nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf": "6a9173365c18d9597b8afb84b1065051",
"factor-nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf": "ad72f00c2e15fe9de0e809de8ee2f32e",
"factor-nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Regular-400.otf": "b2703f18eee8303425a5342dba6958db",
"factor-nav/assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"factor-nav/assets/FontManifest.json": "2a3f09429db12146b660976774660777",
"factor-nav/assets/fonts/MaterialIcons-Regular.otf": "776e5bea0c81709b3adc2cb7debf5396",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"main.dart.js": "baa26eb578d54ee4aea727e5877d5dd5",
"project_nav/index.html": "fc22b83d6491e049d49af473da099edf",
"project_nav/flutter_bootstrap.js": "fc1b451c9b484e652d17ade1dcdb5265",
"project_nav/version.json": "a49baf906374d2df44680e9ca61cc3d8",
"project_nav/canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"project_nav/canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"project_nav/canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"project_nav/canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"project_nav/canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"project_nav/canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"project_nav/canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"project_nav/canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"project_nav/canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"project_nav/canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"project_nav/canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"project_nav/canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"project_nav/flutter.js": "888483df48293866f9f41d3d9274a779",
"project_nav/main.dart.js": "796f44ff8f28689f91a5068e49050dc1",
"project_nav/assets/NOTICES": "cb7180c0bd512c3683b10353abef06fd",
"project_nav/assets/AssetManifest.bin": "dc086cfcf5f3ac1b5d84beb38865b67e",
"project_nav/assets/AssetManifest.bin.json": "a2520657bd90f1f2d878c27d421e08e2",
"project_nav/assets/AssetManifest.json": "e627df0820f857ca3725cb3f8c9691ba",
"project_nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf": "3dde390ca334cb53d274061de544a934",
"project_nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf": "ad72f00c2e15fe9de0e809de8ee2f32e",
"project_nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Regular-400.otf": "b8d17287500cc2e055ade21d470ab9c9",
"project_nav/assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"project_nav/assets/FontManifest.json": "2a3f09429db12146b660976774660777",
"project_nav/assets/fonts/MaterialIcons-Regular.otf": "97fdcb9c1babac9f11c16c68edc5b10a",
"mock_apps/plot_viewer.html": "ea1e3658bcf0f9704e1791737d4d377b",
"mock_apps/project_nav.html": "7c2d214cfa741ad5fbce229457718dc3",
"mock_apps/task_manager.html": "9899c7fa97dd5200da8dd1bf09a03ab9",
"mock_apps/ai_chat.html": "b844411254070d8de25f9b5c4f54efb9",
"mock_apps/toolbar.html": "6c34f57fda26a5c768f5edac128d1530",
"mock_apps/team_nav.html": "2a0abd9baffbc3a825b21bc46a3ecb06",
"assets/NOTICES": "7bce23a337558dd4860e467bc3d3ad71",
"assets/AssetManifest.bin": "0b0a3415aad49b6e9bf965ff578614f9",
"assets/AssetManifest.bin.json": "a1fee2517bf598633e2f67fcf3e26c94",
"assets/AssetManifest.json": "99914b932bd37a50b983c5e7c90ae93b",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/FontManifest.json": "7b2a36307916a9721811788013e65289",
"assets/fonts/MaterialIcons-Regular.otf": "7bf2dc5f2011496e82610440566c1506"};
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
