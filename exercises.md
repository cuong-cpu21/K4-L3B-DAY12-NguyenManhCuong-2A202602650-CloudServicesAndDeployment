# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Mạnh Cường  Mã học viên: 2A202602650

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Khi deploy service lên môi trường cloud (Railway/Render) hoặc staging, nếu người quản trị vô tình quên khai báo biến `AGENT_API_KEY` trong dashboard, cơ chế "fail fast" sẽ khiến ứng dụng ném ngoại lệ `ValidationError` và dừng tiến trình ngay lập tức. Nền tảng cloud sẽ ghi nhận service bị crash/unhealthy ngay tại khâu khởi động, ngăn chặn traffic trỏ tới container lỗi và cảnh báo cho developer biết ngay lập tức.
Ngược lại, nếu để giá trị mặc định như `"changeme"`, service vẫn khởi động trơn tru và báo 200 OK. Khi đó, service công khai trên Internet sẽ bị bất kỳ ai (kể cả web crawler và bot quét bảo mật) khai thác bằng khóa mặc định `"changeme"`. Kẻ xấu có thể gọi API vô tội vạ, làm lộ dữ liệu hoặc đốt sạch ngân sách LLM mà hệ thống không hề cảnh báo cho đến khi nhận hóa đơn.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log JSON thu được:
`{"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T03:00:15.123456+00:00", "user_id": "sv-123", "tokens_in": 12, "tokens_out": 45, "cost_usd": 0.000035}`

Hai việc làm được với dòng log JSON này mà `print("đã trả lời xong")` không làm được:
1. **Lọc, tìm kiếm và truy vấn trường dữ liệu có cấu trúc trên hệ thống quản lý log tập trung** (như Datadog, CloudWatch, Grafana Loki, Logtail): Ta có thể lọc chính xác mọi request của một user cụ thể (`user_id = "sv-123"`), tính tổng chi phí `sum(cost_usd)` theo từng khoảng thời gian hoặc thống kê số token tiêu thụ mà không cần phải viết regex bóc tách chuỗi phức tạp và dễ gãy.
2. **Thiết lập cảnh báo (Alerting) và đo lường tự động (Metrics Dashboard)**: Có thể dễ dàng định nghĩa các rule cảnh báo tự động khi phát hiện event có `cost_usd > 0.05` hoặc đếm tần suất event `ask_completed` để vẽ biểu đồ throughput/latency theo thời gian thực mà hệ thống giám sát máy tính đọc hiểu trực tiếp được.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1020 MB |
| Multi-stage | 185 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần dung lượng chênh lệch (~835 MB) bao gồm:
1. **Trình biên dịch và công cụ build hệ thống**: Bản base `python:3.11` đầy đủ chứa trình biên dịch GCC, G++, build-essential, header files C/C++, git, package manager và các thư viện hệ điều hành Debian đầy đủ. Trong khi đó, bản multi-stage sử dụng `python:3.11-slim` cho runtime đã lược bỏ toàn bộ toolchain biên dịch không cần thiết.
2. **Bộ nhớ đệm (Cache) của pip và file tạm**: Ở stage builder, quá trình tải và cài đặt packages tạo ra rất nhiều file tạm và cache. Trong multi-stage, ta chỉ copy thư mục virtualenv `/opt/venv` thành phẩm sang runtime stage mà không mang theo bất kỳ file rác, compiler hay cache nào.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

- **Khi sửa một ký tự trong `app/main.py`**:
  - Các layer trước đó bao gồm: `FROM python:3.11-slim AS builder`, `WORKDIR /build`, `python -m venv`, `COPY requirements.txt .`, `RUN pip install ...`, cũng như các layer đầu của runtime (`RUN groupadd && useradd`, `COPY --from=builder /opt/venv /opt/venv`) đều không có file đầu vào thay đổi nên được Docker **tận dụng 100% từ Cache (CACHED)**. Quá trình build hoàn thành chỉ trong chưa đầy 1 giây.
  - Chỉ có layer `COPY --chown=appuser:appgroup . .` và các layer kế tiếp (`USER`, `EXPOSE`, `CMD`) là phải thực thi lại.
- **Nếu đặt `COPY . .` lên trước `RUN pip install`**:
  - Mỗi khi sửa bất kỳ file mã nguồn nào, checksum của layer `COPY . .` sẽ thay đổi, làm mất hiệu lực toàn bộ cache từ bước đó trở đi (cache busting).
  - Hệ quả là Docker bắt buộc phải chạy lại toàn bộ lệnh `RUN pip install`, tải và cài đặt lại tất cả thư viện từ đầu ở mỗi lần build, gây lãng phí thời gian và băng thông nghiêm trọng.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

**Chuỗi sự kiện tấn công**:
1. Kẻ tấn công phát hiện một lỗ hổng trong code ứng dụng (ví dụ: lỗi Command Injection, Unsafe Deserialization hoặc lỗ hổng RCE từ thư viện bên thứ ba).
2. Kẻ tấn công gửi payload độc hại để thực thi lệnh shell tùy ý bên trong container. Nếu container không khai báo `USER`, tiến trình sẽ chạy dưới quyền `root` (UID 0) bên trong container.
3. Kẻ tấn công có toàn quyền root trong container, từ đó có thể khai thác các cơ chế như mount nhầm Docker socket (`/var/run/docker.sock`), lỗi bảo mật của kernel Linux, hoặc lỗ hổng container runtime (breakout vulnerability trong `runc`) để thoát ra ngoài không gian của container (container breakout).
4. Do tiến trình trong container có UID 0 tương ứng với UID 0 trên Linux host (nếu không bật user namespace remap), kẻ tấn công chính thức chiếm quyền điều khiển root tối cao của toàn bộ máy chủ vật lý host.

**Lệnh `USER` cắt đứt chuỗi ở đâu**:
Lệnh `USER appuser` cắt đứt chuỗi tấn công ngay tại **Bước 2**: Tiến trình Python bị giới hạn quyền chặt chẽ dưới user thường không có đặc quyền (UID 1000). Kẻ tấn công nếu có kích hoạt được shell cũng không thể cài đặt phần mềm, không sửa được file hệ thống, không truy cập được tài nguyên bảo mật và không có đủ quyền hạn để thực hiện các kỹ thuật leo thang đặc quyền hay container escape ra ngoài máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

- **Con số tối đa**: Người dùng có thể gửi tối đa **20 request trong 2 giây liên tiếp**.
- **Cách đạt được**:
  - Với cơ chế đếm theo phút đồng hồ cố định (fixed window): hạn mức được reset về 0 tại mỗi mốc chuyển giao phút (giây `00`).
  - Người dùng gửi 10 request dồn dập vào giây cuối cùng của phút thứ nhất (`10:00:59`). Hệ thống kiểm tra thấy chưa vượt quá 10 req/phút nên cho qua toàn bộ 10 request.
  - Ngay 1 giây sau đó (`10:01:00` hoặc `10:01:01`), đồng hồ hệ thống bước sang phút mới và bộ đếm tự động reset về 0. Người dùng lập tức gửi tiếp 10 request nữa trong giây này.
  - Tổng cộng từ `10:00:59` đến `10:01:01` (chỉ đúng 2 giây), người dùng đã gửi thành công **20 request** mà không vi phạm quy tắc đếm theo phút cố định, tạo ra một đột biến tải gấp đôi cho server.
Sliding window 60s giải quyết triệt để lỗi này bằng cách luôn tính chính xác số request trong khoảng thời gian `[now - 60s, now]`.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

- **Khác nhau cơ bản**:
  - Rate limit bảo vệ **tần suất và tài nguyên tính toán/hạ tầng mạng** trong ngắn hạn (ngăn server bị nghẽn mạng, sập socket, DDoS theo từng giây/phút).
  - Cost guard bảo vệ **ngân sách tài chính và hóa đơn API LLM** trong dài hạn (kiểm soát số tiền tích lũy dựa trên số lượng token tiêu thụ theo tháng).
- **Tình huống Rate limit cho qua nhưng Cost guard chặn**:
  - Người dùng chỉ gửi 1 request duy nhất trong ngày (tần suất 1 req/ngày << 10 req/phút nên Rate limit cho qua hoàn toàn). Tuy nhiên, người dùng này trong những ngày trước đó đã tích lũy chi phí đạt ngưỡng 10.0 USD/tháng. Cost guard kiểm tra thấy ngân sách vượt mức và lập tức chặn lại, trả về mã HTTP `402 Payment Required`.
- **Tình huống Cost guard cho qua nhưng Rate limit chặn**:
  - Người dùng mới tạo tài khoản, chưa tiêu một xu nào (ngân sách còn nguyên 10.0 USD). Tuy nhiên, client bị lỗi vòng lặp hoặc cố tình spam liên tiếp 15 request chỉ trong vòng 3 giây. Mặc dù tổng chi phí của 15 câu hỏi ngắn này chỉ mất vài phần nghìn USD (thỏa mãn ngân sách), nhưng vì tần suất vượt quá 10 req/phút nên Rate limit sẽ chặn từ request thứ 11 và trả về mã HTTP `429 Too Many Requests`.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện xảy ra khi gộp chung và kiểm tra Redis ở liveness probe:
1. Redis gặp sự cố mạng hoặc khởi động lại, mất kết nối trong 30 giây.
2. Bộ điều phối cụm (Docker Swarm/Kubernetes/ECS) định kỳ thăm dò endpoint `/health` trên cả 3 container agent (ví dụ mỗi 10 giây/lần).
3. Do Redis mất kết nối, endpoint `/health` kiểm tra thất bại và trả về mã `503 Service Unavailable`.
4. Orchestrator suy luận rằng tiến trình của cả 3 container agent đã bị hỏng/treo, và kích hoạt hành vi tự phục hồi của liveness probe: **kill và restart lại toàn bộ 3 container agent**.
5. Ba container mới khởi động lại, tiếp tục gọi `/health`. Nhưng vì Redis vẫn chưa hồi phục trong 30 giây đó, `/health` lại trả về 503.
6. Orchestrator tiếp tục kill và restart các container liên tục, dẫn đến hiện tượng **Restart Storm (Cơn bão restart liên hoàn)**. Toàn bộ cụm sập hoàn toàn, tài nguyên CPU/RAM máy host bị nghẽn do liên tục khởi động container, và các tiến trình đang xử lý dở dang bị xóa sổ.
*Giải pháp đúng*: `/health` (liveness) chỉ kiểm tra process Python còn chạy hay không. Còn `/ready` (readiness) kiểm tra Redis để Load Balancer chỉ tạm thời ngưng định tuyến traffic vào container cho đến khi Redis kết nối trở lại mà không giết tiến trình.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

- **Khi lưu bằng dict trong bộ nhớ RAM của Python**:
  - Mỗi container trong cụm 3 instance có một không gian bộ nhớ RAM riêng biệt, hoàn toàn cô lập với nhau.
  - Khi người dùng gửi liên tiếp các câu hỏi tới cùng một địa chỉ, Load Balancer sẽ chia tải phân phối các request tới các instance khác nhau (ví dụ theo Round-Robin: Container A -> Container B -> Container C -> Container A...).
  - Kết quả là `history_length` nhận được sẽ nhảy lộn xộn và không tăng tuần tự: Request 1 rơi vào A (`history_length = 0`), Request 2 rơi vào B (`history_length = 0`), Request 3 rơi vào C (`history_length = 0`), Request 4 quay lại A (`history_length = 2`)... Người dùng sẽ thấy agent liên tục bị "mất trí nhớ", không thể đối thoại liền mạch.
- **Khi lưu trong Redis (Stateless)**:
  - Cả 3 container đều dùng chung một kho lưu trữ tập trung Redis. Dù request được định tuyến tới container nào, container đó cũng đọc và ghi vào cùng một key `history:{user_id}`, giúp `history_length` tăng đều đặn theo mỗi lượt hỏi (0 -> 2 -> 4 -> 6...), bảo toàn ngữ cảnh hội thoại nhất quán.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- **Thông báo lỗi**:
  Trên Railway/Render runtime log hiển thị: `Container failed to start / Healthcheck timeout: Connection refused to port 8000 on 0.0.0.0` hoặc `Service failed to respond on port $PORT within 60s`.
- **Cách tìm ra nguyên nhân**:
  Xem runtime logs và mục Network Settings trên Dashboard của platform: Nền tảng cloud không cố định cổng 8000 mà tự động gán một cổng ngẫu nhiên thông qua biến môi trường `$PORT` (ví dụ `PORT=49152`) và chỉ mở traffic vào cổng đó. Nếu ứng dụng trong Dockerfile hard-code cổng 8000 (`uvicorn --port 8000`), reverse proxy của cloud không thể kết nối tới app, dẫn tới timeout và crash container.
- **Cách sửa**:
  1. Trong [Dockerfile](Dockerfile), sửa lệnh chạy khởi động để đọc cổng động từ biến môi trường của nền tảng:
     `CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]`
  2. Trong [app/config.py](app/config.py), cấu hình `Settings` với trường `port: int = 8000` để Pydantic tự động map giá trị từ biến môi trường `PORT` do platform cung cấp.
