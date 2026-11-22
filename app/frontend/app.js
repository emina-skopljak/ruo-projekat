"use strict";

const API = "/api/notes";
const el = {
  status: document.getElementById("status"),
  form: document.getElementById("note-form"),
  input: document.getElementById("note-input"),
  submit: document.getElementById("note-submit"),
  list: document.getElementById("notes"),
};

function setStatus(text, isError = false) {
  el.status.textContent = text;
  el.status.classList.toggle("error", isError);
}

function formatTime(value) {
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "";
  return d.toLocaleString("bs-BA", { dateStyle: "short", timeStyle: "short" });
}

function render(notes) {
  el.list.replaceChildren();
  for (const note of notes) {
    const li = document.createElement("li");
    const body = document.createElement("span");
    body.textContent = note.body;
    const time = document.createElement("span");
    time.className = "time";
    time.textContent = formatTime(note.created_at);
    li.append(body, time);
    el.list.append(li);
  }
  if (notes.length === 0) {
    setStatus("Nema zadataka. Dodaj prvi.");
  } else {
    setStatus(`Ukupno: ${notes.length}`);
  }
}

async function load() {
  try {
    const res = await fetch(API, { headers: { Accept: "application/json" } });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    render(await res.json());
  } catch (err) {
    setStatus(`Greška pri učitavanju: ${err.message}`, true);
  }
}

el.form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const body = el.input.value.trim();
  if (!body) return;

  el.submit.disabled = true;
  try {
    const res = await fetch(API, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ body }),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    el.input.value = "";
    await load();
  } catch (err) {
    setStatus(`Greška pri upisu: ${err.message}`, true);
  } finally {
    el.submit.disabled = false;
    el.input.focus();
  }
});

load();
