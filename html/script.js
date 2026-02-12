const container = document.getElementById("container");
const speeches = {};

window.addEventListener("message", function(event) {
    const data = event.data;

    if (data.type === "updateSpeech") {

        if (!speeches[data.netId]) {
            const div = document.createElement("div");
            div.className = "speech";
            container.appendChild(div);
            speeches[data.netId] = div;
        }

        const speech = speeches[data.netId];

        if (data.visible === false) {
            speech.style.display = "none";
            return;
        }

        speech.style.display = "block";

        if (data.text) {
            speech.innerText = data.text;
        }

        const screenWidth = window.innerWidth;
        const screenHeight = window.innerHeight;

        speech.style.left = (data.x * screenWidth) + "px";
        speech.style.top = (data.y * screenHeight) + "px";
    }

    if (data.type === "removeSpeech") {
        if (speeches[data.netId]) {
            speeches[data.netId].remove();
            delete speeches[data.netId];
        }
    }
});
