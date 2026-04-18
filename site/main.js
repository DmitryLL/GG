const badge = document.getElementById("status-badge");

if (badge) {
  const labels = [
    "build: local showcase",
    "mode: static web page",
    "art: pixel prototype",
    "stack: godot + nakama",
  ];

  let index = 0;
  window.setInterval(() => {
    index = (index + 1) % labels.length;
    badge.textContent = labels[index];
  }, 2400);
}
