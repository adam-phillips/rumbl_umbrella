import Player from "./player"
import {Presence} from "phoenix"

let Video = {
  init(socket, element) {
    if (!element) {
      return
    }
    let playerId = element.getAttribute("data-player-id");
    let videoId = element.getAttribute("data-id");
    socket.connect();
    Player.init(element.id, playerId, () => {
      this.onReady(videoId, socket)
    })
  },

  onReady(videoId, socket) {
    let msgContainer = document.getElementById("msg-container");
    let msgInput = document.getElementById("msg-input");
    let postButton = document.getElementById("msg-submit");
    let userList = document.getElementById("user-list");
    let lastSeenId = 0;
    // Below channel for hooking into Phoenix channel. Include `last_seen` so
    // if a client disconnects they don't see duplicate annotations
    let vidChannel = socket.channel("videos:" + videoId, () => {
      return {last_seen_id: lastSeenId}
    });

    // Create new Presence object from `vidChannel`
    let presence = new Presence(vidChannel);

    // Render users as list items when users join or leave
    presence.onSync(() => {
      userList.innerHTML = presence.list((id, {user: user, metas: [first, ...rest]}) => {
        let count = rest.length + 1;
        return `<li>${user.username}: (${count})</li>`
      }).join("")
    });

    // Push new annotation when button is pressed, then clear input
    postButton.addEventListener("click", e => {
      let payload = {body: msgInput.value, at: Player.getCurrentTime()};
      vidChannel.push("new_annotation", payload)
        .receive("error", e => console.log(e));
      msgInput.value = ""
    });

    // Render a new annotation in the message container and track the last
    // seen annotation
    vidChannel.on("new_annotation", (resp) => {
      lastSeenId = resp.id;
      this.renderAnnotation(msgContainer, resp)
    });

    // Add listener so if annotation is clicked the player moves to the
    // annotation 'at' time
    msgContainer.addEventListener("click", e => {
      e.preventDefault();
      let seconds = e.target.getAttribute("data-seek") || e.target.parentNode.getAttribute("data-seek");
      if (!seconds) {
        return
      }
      Player.seekTo(seconds)
    });

    // Join the video channel: lib/rumbl_web/channels/video_channel.ex
    // Track the ids of last seen annotations and if present pass the
    // annotation to be scheduled for display
    vidChannel.join()
      .receive("ok", resp => {
        let ids = resp.annotations.map(ann => ann.id);
        if (ids.length > 0) {
          lastSeenId = Math.max(...ids)
        }
        this.scheduleMessages(msgContainer, resp.annotations)
      })
      .receive("error", reason => console.log("join failed", reason));
  },

  esc(str) {
    let div = document.createElement("div");

    div.appendChild(document.createTextNode(str));
    return div.innerHTML
  },

  // Render annotations in container with formatted time prepended
  renderAnnotation(msgContainer, {user, body, at}) {
    let template = document.createElement("div");

    template.innerHTML = `
    <a href="#" data-seek="${this.esc(at)}">
      [${this.formatTime(at)}]
      <b>${this.esc(user.username)}</b>: ${this.esc(body)}
    </a>
    `;
    msgContainer.appendChild(template);
    msgContainer.scrollTop = msgContainer.scrollHeight
  },

  // Interval timer that fires every second, calling `renderAtTime` with the
  // message container, current player time, and annotations
  scheduleMessages(msgContainer, annotations) {
    clearTimeout(this.scheduleTimer);
    this.scheduleTimer = setTimeout(() => {
      let ctime = Player.getCurrentTime();
      let remaining = this.renderAtTime(annotations, ctime, msgContainer);
      this.scheduleMessages(msgContainer, remaining)
    }, 1000)
  },

  // Filter messages by time, rendering those with an 'at' time less than the
  // current player time. Return true for the others so they can be filtered
  // on the next call from `scheduleMessages`
  renderAtTime(annotations, seconds, msgContainer) {
    return annotations.filter(ann => {
      if (ann.at > seconds) {
        return true
      } else {
        this.renderAnnotation(msgContainer, ann);
        return false
      }
    })
  },

  // Format the 'at' time for an annotation to match desired format
  formatTime(at) {
    let date = new Date(null);
    date.setSeconds(at / 1000);
    return date.toISOString().substr(14, 5)
  }
};
export default Video
