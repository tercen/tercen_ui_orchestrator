'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "0b0a3415aad49b6e9bf965ff578614f9",
"assets/AssetManifest.bin.json": "a1fee2517bf598633e2f67fcf3e26c94",
"assets/AssetManifest.json": "99914b932bd37a50b983c5e7c90ae93b",
"assets/FontManifest.json": "7b2a36307916a9721811788013e65289",
"assets/fonts/MaterialIcons-Regular.otf": "5c1c7d67e67c55f022ae0ab9572ae26f",
"assets/NOTICES": "be82334c374e2880736f692a16cb31dd",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"factor-nav/assets/AssetManifest.bin": "d07a484f96dc04efe00fb7dc5dae99d5",
"factor-nav/assets/AssetManifest.bin.json": "94770df6ee426825ac5e16b2687ed5b6",
"factor-nav/assets/AssetManifest.json": "ea66be726abc225e92ac802d1f12856a",
"factor-nav/assets/FontManifest.json": "2a3f09429db12146b660976774660777",
"factor-nav/assets/fonts/MaterialIcons-Regular.otf": "776e5bea0c81709b3adc2cb7debf5396",
"factor-nav/assets/NOTICES": "89c8d799886a7d437f67aacf65ad80f5",
"factor-nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf": "ad72f00c2e15fe9de0e809de8ee2f32e",
"factor-nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Regular-400.otf": "b2703f18eee8303425a5342dba6958db",
"factor-nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf": "6a9173365c18d9597b8afb84b1065051",
"factor-nav/assets/shaders/ink_sparkle.frag": "9bb2aaa0f9a9213b623947fa682efa76",
"factor-nav/canvaskit/canvaskit.js": "1b6f288ce484225c079db75751f22814",
"factor-nav/canvaskit/canvaskit.js.symbols": "a3b4c42fca4cdf168ac2718d2d09bc7a",
"factor-nav/canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"factor-nav/canvaskit/chromium/canvaskit.js": "0d3e893c15ead7da6d36efe877694617",
"factor-nav/canvaskit/chromium/canvaskit.js.symbols": "03d31667dc4f5676bafee152fe8ff4d7",
"factor-nav/canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"factor-nav/canvaskit/skwasm.js": "66504b1416ee7a68aee25f965a90949c",
"factor-nav/canvaskit/skwasm.js.symbols": "09f5d843a50cf276b2dba6fc466b98e6",
"factor-nav/canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"factor-nav/canvaskit/skwasm_heavy.js": "31e5a202dc9ca33e695bc30bca93566c",
"factor-nav/canvaskit/skwasm_heavy.js.symbols": "7f3cadcdd3b8e95e0160e83d82085ef6",
"factor-nav/canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"factor-nav/flutter.js": "3265c4a743599232db370a9249855db3",
"factor-nav/flutter_bootstrap.js": "e0ed859c1ae88ebdc4ec779e0311fdb7",
"factor-nav/index.html": "bb7505df6b5466ba9e588424b8828bd3",
"factor-nav/main.dart.js": "ef49b9a676773b5aca53cc9709ecc331",
"factor-nav/version.json": "a95218349282dff1cb154a9541c63f2c",
"factor_nav/assets/AssetManifest.bin": "d07a484f96dc04efe00fb7dc5dae99d5",
"factor_nav/assets/AssetManifest.bin.json": "94770df6ee426825ac5e16b2687ed5b6",
"factor_nav/assets/AssetManifest.json": "ea66be726abc225e92ac802d1f12856a",
"factor_nav/assets/FontManifest.json": "2a3f09429db12146b660976774660777",
"factor_nav/assets/fonts/MaterialIcons-Regular.otf": "776e5bea0c81709b3adc2cb7debf5396",
"factor_nav/assets/NOTICES": "89c8d799886a7d437f67aacf65ad80f5",
"factor_nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf": "ad72f00c2e15fe9de0e809de8ee2f32e",
"factor_nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Regular-400.otf": "b2703f18eee8303425a5342dba6958db",
"factor_nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf": "6a9173365c18d9597b8afb84b1065051",
"factor_nav/assets/shaders/ink_sparkle.frag": "9bb2aaa0f9a9213b623947fa682efa76",
"factor_nav/canvaskit/canvaskit.js": "1b6f288ce484225c079db75751f22814",
"factor_nav/canvaskit/canvaskit.js.symbols": "a3b4c42fca4cdf168ac2718d2d09bc7a",
"factor_nav/canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"factor_nav/canvaskit/chromium/canvaskit.js": "0d3e893c15ead7da6d36efe877694617",
"factor_nav/canvaskit/chromium/canvaskit.js.symbols": "03d31667dc4f5676bafee152fe8ff4d7",
"factor_nav/canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"factor_nav/canvaskit/skwasm.js": "66504b1416ee7a68aee25f965a90949c",
"factor_nav/canvaskit/skwasm.js.symbols": "09f5d843a50cf276b2dba6fc466b98e6",
"factor_nav/canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"factor_nav/canvaskit/skwasm_heavy.js": "31e5a202dc9ca33e695bc30bca93566c",
"factor_nav/canvaskit/skwasm_heavy.js.symbols": "7f3cadcdd3b8e95e0160e83d82085ef6",
"factor_nav/canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"factor_nav/flutter.js": "3265c4a743599232db370a9249855db3",
"factor_nav/flutter_bootstrap.js": "adacab5601249bfec635042ec19176c2",
"factor_nav/index.html": "bb7505df6b5466ba9e588424b8828bd3",
"factor_nav/main.dart.js": "be911b3cab2df333bd70259b29542323",
"factor_nav/version.json": "a95218349282dff1cb154a9541c63f2c",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"flutter_bootstrap.js": "1ea222f4cc92d39b6b5a314708884eb2",
"index.html": "fe0a5d1c0150247e9944f1364c0b97cd",
"/": "fe0a5d1c0150247e9944f1364c0b97cd",
"main.dart.js": "ebaa000c4383ea4531b89c6870b58d5a",
"manifest.json": "3a36132066d4bec134e9ec046671e9f7",
"mock_apps/ai_chat.html": "c4498bf9e81190bc5ea4db64301b550c",
"mock_apps/plot_viewer.html": "d44521d8b6a125afa55381e21005a0e2",
"mock_apps/project_nav.html": "e73e5a7b6dcd2af4074797553dfd5636",
"mock_apps/task_manager.html": "e435af00d3ae08765b25922c56db56ca",
"mock_apps/team_nav.html": "f078ed9a7151a7f7923c396481d95529",
"mock_apps/toolbar.html": "58b8e0f1ef122172f542348b16686b30",
"project_nav/assets/AssetManifest.bin": "dc086cfcf5f3ac1b5d84beb38865b67e",
"project_nav/assets/AssetManifest.bin.json": "a2520657bd90f1f2d878c27d421e08e2",
"project_nav/assets/AssetManifest.json": "e627df0820f857ca3725cb3f8c9691ba",
"project_nav/assets/FontManifest.json": "2a3f09429db12146b660976774660777",
"project_nav/assets/fonts/MaterialIcons-Regular.otf": "97fdcb9c1babac9f11c16c68edc5b10a",
"project_nav/assets/NOTICES": "89c8d799886a7d437f67aacf65ad80f5",
"project_nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf": "ad72f00c2e15fe9de0e809de8ee2f32e",
"project_nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Regular-400.otf": "b8d17287500cc2e055ade21d470ab9c9",
"project_nav/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf": "3dde390ca334cb53d274061de544a934",
"project_nav/assets/shaders/ink_sparkle.frag": "9bb2aaa0f9a9213b623947fa682efa76",
"project_nav/canvaskit/canvaskit.js": "1b6f288ce484225c079db75751f22814",
"project_nav/canvaskit/canvaskit.js.symbols": "a3b4c42fca4cdf168ac2718d2d09bc7a",
"project_nav/canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"project_nav/canvaskit/chromium/canvaskit.js": "0d3e893c15ead7da6d36efe877694617",
"project_nav/canvaskit/chromium/canvaskit.js.symbols": "03d31667dc4f5676bafee152fe8ff4d7",
"project_nav/canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"project_nav/canvaskit/skwasm.js": "66504b1416ee7a68aee25f965a90949c",
"project_nav/canvaskit/skwasm.js.symbols": "09f5d843a50cf276b2dba6fc466b98e6",
"project_nav/canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"project_nav/canvaskit/skwasm_heavy.js": "31e5a202dc9ca33e695bc30bca93566c",
"project_nav/canvaskit/skwasm_heavy.js.symbols": "7f3cadcdd3b8e95e0160e83d82085ef6",
"project_nav/canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"project_nav/flutter.js": "3265c4a743599232db370a9249855db3",
"project_nav/flutter_bootstrap.js": "10e5be2a9268dc659399e3fda14faf8f",
"project_nav/index.html": "67335e8287be5ab26fbc7536c2e7e40f",
"project_nav/main.dart.js": "994b07f586f936ba7446a66a013b61fd",
"project_nav/version.json": "a49baf906374d2df44680e9ca61cc3d8",
"step_viewer/assets/AssetManifest.bin": "d07a484f96dc04efe00fb7dc5dae99d5",
"step_viewer/assets/AssetManifest.bin.json": "94770df6ee426825ac5e16b2687ed5b6",
"step_viewer/assets/AssetManifest.json": "ea66be726abc225e92ac802d1f12856a",
"step_viewer/assets/FontManifest.json": "2a3f09429db12146b660976774660777",
"step_viewer/assets/fonts/MaterialIcons-Regular.otf": "699f33287223cbff107f42cb405db267",
"step_viewer/assets/NOTICES": "89c8d799886a7d437f67aacf65ad80f5",
"step_viewer/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf": "1fcba7a59e49001aa1b4409a25d425b0",
"step_viewer/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Regular-400.otf": "b2703f18eee8303425a5342dba6958db",
"step_viewer/assets/packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Free-Solid-900.otf": "6a9173365c18d9597b8afb84b1065051",
"step_viewer/assets/shaders/ink_sparkle.frag": "9bb2aaa0f9a9213b623947fa682efa76",
"step_viewer/canvaskit/canvaskit.js": "1b6f288ce484225c079db75751f22814",
"step_viewer/canvaskit/canvaskit.js.symbols": "a3b4c42fca4cdf168ac2718d2d09bc7a",
"step_viewer/canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"step_viewer/canvaskit/chromium/canvaskit.js": "0d3e893c15ead7da6d36efe877694617",
"step_viewer/canvaskit/chromium/canvaskit.js.symbols": "03d31667dc4f5676bafee152fe8ff4d7",
"step_viewer/canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"step_viewer/canvaskit/skwasm.js": "66504b1416ee7a68aee25f965a90949c",
"step_viewer/canvaskit/skwasm.js.symbols": "09f5d843a50cf276b2dba6fc466b98e6",
"step_viewer/canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"step_viewer/canvaskit/skwasm_heavy.js": "31e5a202dc9ca33e695bc30bca93566c",
"step_viewer/canvaskit/skwasm_heavy.js.symbols": "7f3cadcdd3b8e95e0160e83d82085ef6",
"step_viewer/canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"step_viewer/flutter.js": "3265c4a743599232db370a9249855db3",
"step_viewer/flutter_bootstrap.js": "dcca1ea0af741eecd5b7125cd5f5ae53",
"step_viewer/ggrs/bootstrap.js": "a923e95bcfd9bb9e7576fc9b48f4fda2",
"step_viewer/ggrs/bootstrap.js.bak": "7b3634530ec906dd13c3d86ade113fa9",
"step_viewer/ggrs/bootstrap_v2.js": "9d8b5e65e089ea8fd1d4896a514bfcbf",
"step_viewer/ggrs/bootstrap_v2.js.bak": "bea0f2fb801a39ba45b4af6e43b0b3bc",
"step_viewer/ggrs/bootstrap_v3.js": "96e1cb907deeca291072471e42631890",
"step_viewer/ggrs/bootstrap_v3.js.bak": "16d78d2a1cecd66bfdf2d67cb5f7a1cb",
"step_viewer/ggrs/ggrs_gpu.js": "ae2bab693b2582b92ba8801b72a6002d",
"step_viewer/ggrs/ggrs_gpu.js.bak": "bda81485b28d248fe19dff07eba310a9",
"step_viewer/ggrs/ggrs_gpu_v2.js": "8aa3eb3e62c0b2474775de8e11bb19ca",
"step_viewer/ggrs/ggrs_gpu_v2.js.bak": "33565e72c44a3e02dca441a8cbdf60e9",
"step_viewer/ggrs/ggrs_gpu_v3.js": "3529ef9409ffeff41b439a5a2e73ddce",
"step_viewer/ggrs/ggrs_gpu_v3.js.bak": "86e7ba0065c6baf3881d9ac751cc6d36",
"step_viewer/ggrs/interaction_manager.js": "4efd2f2dc16e85cf360a95c614111cb8",
"step_viewer/ggrs/interaction_manager.js.bak": "280500dd4d1e2bbc2f911ffc43c7aa4b",
"step_viewer/ggrs/mock_data_worker.js": "e34ddd4bf9f6f8fad52089db0790918b",
"step_viewer/ggrs/pkg/ggrs_wasm.d.ts": "4d1e7a01f93dbd65968c4a0ea9899353",
"step_viewer/ggrs/pkg/ggrs_wasm.js": "809ab4e9789256eec90d2826236cac44",
"step_viewer/ggrs/pkg/ggrs_wasm_bg.wasm": "537cc8131632f6cb6b487c41ee89e688",
"step_viewer/ggrs/pkg/ggrs_wasm_bg.wasm.d.ts": "7d443475ad217f1d218d77d69d7b0c50",
"step_viewer/ggrs/pkg/package.json": "652edda203feaf56034c057eb4f523cf",
"step_viewer/ggrs/plot_orchestrator.js": "d7b77dbe528acaaeefebfe17a8d84b86",
"step_viewer/ggrs/plot_state.js": "2bd5a99a4c4b9465260dfe0f9aa97575",
"step_viewer/ggrs/render_coordinator.js": "f994a5babcd83e2680e530be5d7b20e7",
"step_viewer/ggrs/viewport_state.js": "6c9294f00b203ce25bda574f1824f37a",
"step_viewer/index.html": "af4d9fd3e101bcc3d9a4ff156fa87eea",
"step_viewer/main.dart.js": "ec8fc954568661e37178f720bb2a5de8",
"step_viewer/test_chrome.html": "16c825cfb5edecdc168b541a1df6679e",
"step_viewer/test_coordinator.html": "5ad2409c94c502de110885522347a0e7",
"step_viewer/test_debug.html": "bd561bcef0764d86ddc398b0e8b397b4",
"step_viewer/test_interaction.html": "c78206bf600f8054311f73d2f38c0e26",
"step_viewer/test_simple.html": "d1600bd373968b57d1ca2952f3496e17",
"step_viewer/test_streaming.html": "92f8ded7926681b6052a5414ef81ad92",
"step_viewer/test_v3_render.html": "fb8888127c267236295a242a0441c482",
"step_viewer/version.json": "309a5f26d3eb03d39dbf92fb7eb2c23a",
"version.json": "7117ace3c5a191b91533e394d8df6fe3"};
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
