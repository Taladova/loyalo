"use strict";

const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const { ref, uploadBytes, getBytes, deleteObject } = require("firebase/storage");
const { doc, setDoc } = require("firebase/firestore");
const { PROJECT_ID } = require("./emulator_helpers");

let environment;

test.before(async () => {
  environment = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: "127.0.0.1",
      port: 8080,
    },
    storage: {
      host: "127.0.0.1",
      port: 9199,
      rules: fs.readFileSync(
        path.join(__dirname, "../../../config/firebase/pilot/storage.rules"),
        "utf8"
      ),
    },
  });

  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "merchants/merchant-a"), {
      restaurantId: "restaurant-a",
    });
  });
});
test.after(async () => environment.cleanup());

const storageFor = (uid) => environment.authenticatedContext(uid).storage();

test("pilot merchant images are writable only by the owning merchant", async () => {
  const path = "merchants/merchant-a/logo/logo.png";
  const bytes = new Uint8Array([137, 80, 78, 71]);

  await assertSucceeds(uploadBytes(ref(storageFor("merchant-a"), path), bytes, {
    contentType: "image/png",
  }));
  await assertFails(uploadBytes(ref(storageFor("merchant-b"), path), bytes, {
    contentType: "image/png",
  }));
  await assertSucceeds(getBytes(ref(environment.unauthenticatedContext().storage(), path)));
  await assertFails(deleteObject(ref(storageFor("merchant-b"), path)));
  await assertSucceeds(deleteObject(ref(storageFor("merchant-a"), path)));
});

test("pilot Storage rejects unsupported paths and MIME types", async () => {
  const merchant = storageFor("merchant-a");

  await assertFails(uploadBytes(
    ref(merchant, "merchants/merchant-a/logo/logo.pdf"),
    new Uint8Array([1, 2, 3]),
    { contentType: "application/pdf" }
  ));
  await assertFails(uploadBytes(
    ref(merchant, "users/merchant-a/private.png"),
    new Uint8Array([137, 80, 78, 71]),
    { contentType: "image/png" }
  ));
});

test("pilot Storage accepts JPEG, PNG, and WebP up to 8 MiB", async () => {
  const merchant = storageFor("merchant-a");
  const cases = [
    ["logo/logo.jpg", "image/jpeg"],
    ["cover/cover.png", "image/png"],
    ["gallery/photo.webp", "image/webp"],
  ];

  for (const [suffix, contentType] of cases) {
    await assertSucceeds(uploadBytes(
      ref(merchant, `merchants/merchant-a/${suffix}`),
      new Uint8Array([1, 2, 3]),
      { contentType }
    ));
  }

  await assertSucceeds(uploadBytes(
    ref(merchant, "merchants/merchant-a/cover/max-size.jpg"),
    new Uint8Array(8 * 1024 * 1024),
    { contentType: "image/jpeg" }
  ));
  await assertFails(uploadBytes(
    ref(merchant, "merchants/merchant-a/cover/too-large.jpg"),
    new Uint8Array(8 * 1024 * 1024 + 1),
    { contentType: "image/jpeg" }
  ));
});

test("pilot Storage denies client writes and deletes", async () => {
  const path = "merchants/merchant-a/gallery/client.png";
  const client = storageFor("client-a");

  await assertFails(uploadBytes(ref(client, path), new Uint8Array([1, 2, 3]), {
    contentType: "image/png",
  }));
  await assertFails(deleteObject(ref(client, path)));
  await assertFails(uploadBytes(
    ref(client, "merchants/client-a/logo/client.png"),
    new Uint8Array([1, 2, 3]),
    { contentType: "image/png" }
  ));
});
