# PetraScholar

Aplikasi web publik untuk **menelusuri repository Tugas Akhir Universitas Kristen Petra
(UKP)** sekaligus **menghasilkan kerangka proposal Tugas Akhir** dengan bantuan AI.

Aplikasi ini menggantikan cara lama mencari dan menelusuri TA: mahasiswa tidak lagi
menelusuri berkas satu per satu atau bertanya ke setiap dosen satu per satu. Semua data
TA yang sudah terbit dikumpulkan dalam satu tempat, dapat dicari dan difilter, lalu
dijadikan konteks bagi generator proposal agar hasilnya **berdasar pada TA yang benar-benar
ada**, bukan karangan.

> **Ringkas:** Cari TA yang sudah terbit, cek seberapa mirip proposal Anda, lalu buat
> kerangka proposal lengkap sesuai jalur **RISET** atau **PROYEK**.

---

## Daftar Isi

- [Untuk Apa Aplikasi Ini](#untuk-apa-aplikasi-ini)
- [Fitur Utama](#fitur-utama)
- [Tampilan Aplikasi](#tampilan-aplikasi)
- [Cara Kerja Generator Proposal](#cara-kerja-generator-proposal)
- [Arsitektur Teknis](#arsitektur-teknis)
- [Struktur Proyek](#struktur-proyek)
- [Menjalankan Secara Lokal](#menjalankan-secara-lokal)
- [Konfigurasi Environment](#konfigurasi-environment)
- [Daftar API Endpoint](#daftar-api-endpoint)
- [Pengujian](#pengujian)
- [Deployment ke Vercel](#deployment-ke-vercel)
- [Catatan Teknis dan Batasan](#catatan-teknis-dan-batasan)

---

## Untuk Apa Aplikasi Ini

### Masalah yang diselesaikan

1. **Menelusuri TA itu sulit.** Data TA tersebar di banyak berkas dan folder, sehingga
   mahasiswa dari program studi baru tidak tahu TA apa yang sudah pernah dibuat di
   konsentrasi lain. Dampaknya, topik yang sebenarnya sudah pernah diteliti sering
   dipilih kembali, dan penelitian baru bisa jadi tidak orisinal.
2. **Dosen kehilangan waktu untuk pertanyaan yang berulang.** Banyak pertanyaan
   mahasiswa berbentuk sama, misalnya "apakah ide saya ini sudah pernah ada?" atau
   "topik apa yang sedang ramai?", dan sebagian besar bisa dijawab otomatis dari data
   repository.
3. **Menulis proposal itu lambat dan membingungkan.** Banyak aturan proposal TA (jumlah
   bagian, struktur, minimal referensi, format jadwal) harus dihafal. Kesalahan struktur
   sering membuat proposal dikembalikan untuk diperbaiki.

### Solusi yang ditawarkan

Aplikasi ini menggabungkan empat hal dalam satu situs:

| Kebutuhan | Solusi |
| --- | --- |
| Cari dan filter TA yang sudah terbit | Halaman **Search & Explore** dengan pencarian kata kunci (judul, penulis, abstrak) serta filter tahun, program studi, konsentrasi, dan topik |
| Cek apakah proposal sudah mirip TA mana | **Chatbot Similarity** yang mengembalikan 5 TA paling mirip beserta skor dan alasannya |
| Lihat tren riset yang sedang berkembang | **Pemetaan Topik** yang mengelompokkan hasil pencarian ke dalam label topik |
| Menulis kerangka proposal dari ide | **Generator Proposal TA** yang menanyakan jalur RISET atau PROYEK lalu menyusun kerangka lengkap sesuai pedoman konsentrasi |

### Untuk siapa

- **Mahasiswa** yang sedang menyiapkan proposal dan butuh referensi TA yang relevan serta
  kerangka awal yang sesuai aturan.
- **Dosen pembimbing** yang ingin cepat memverifikasi kebaruan (novelty) proposal
  mahasiswa terhadap TA yang sudah terbit.
- **Peneliti** yang ingin melihat sebaran topik riset di suatu program studi.

### Prinsip penggunaan

Aplikasi ini **tidak memuat data pribadi mahasiswa yang belum terbit** dan **tidak
memerlukan login**. Yang tersimpan hanya metadata TA yang sudah dipublikasikan.
Web dapat diakses oleh siapa pun untuk mencari, melihat, dan mengobrol dengan bot.
Jangan pernah memasukkan data pribadi, data rahasia, atau informasi yang belum
dipublikasikan ke kolom pencarian atau kolom chat.

---

## Fitur Utama

### 1. Pencarian dan Browse Repository

- **Search hero** di atas: satu kotak besar untuk mencari judul, penulis, kata kunci,
  atau abstrak, dengan tombol **Cari**.
- **Pencarian hybrid**: vektor semantik (embedding) digabung dengan pencocokan kata
  kunci literal, sehingga hasil tetap relevan walaupun kalimat tidak identik dengan
  judul TA.
- **Kartu publikasi** menampilkan judul, penulis, program studi, konsentrasi, tahun,
  cuplikan abstrak, tag dan kata kunci, tautan sumber, serta **skor kemiripan** ketika
  pencarian dilakukan dengan kata kunci.
- **Navigasi halaman** dengan jumlah total dan rentang data yang sedang tampil.

### 2. Filter di Sidebar Kiri

- **Rentang Tahun**: slider dua arah (dari sampai) yang dibatasi tahun terbit
  terdalam dan terbaru. Tarikannya yang penuh berarti "semua tahun" dan otomatis
  dianggap tidak aktif.
- **Program Studi**: checkbox (Informatika, Sistem Informasi, Teknik Biomedik, dan
  sebagainya).
- **Konsentrasi**: checkbox (Artificial Intelligence, Cyber Security, Data Mining, dan
  sebagainya). Memilih program studi akan otomatis menghapus konsentrasi milik program
  studi lain.
- **Topik**: dropdown dari seluruh kata kunci yang muncul di repository, misalnya
  *computer vision*, *nlp*, atau *mobile*.
- Setiap filter aktif muncul sebagai **chip yang bisa dihapus** di bagian atas hasil.
  Tombol **Reset** mengembalikan tampilan ke kondisi awal.

### 3. Chatbot Similarity dan Pemetaan Topik

- **Cek Similarity**: untuk pertanyaan "Apakah proposal saya mirip TA yang sudah terbit?"
  Generator mengembalikan 5 TA paling mirip dengan **skor** dan **alasan**, misalnya
  "Irisan kata kunci: mobile, absensi".
- **Pemetaan Topik**: menjawab pertanyaan "Topik apa yang paling banyak diteliti tahun
  ini?" dengan pengelompokan hasil ke dalam label topik beserta jumlahnya.
- Setiap jawaban disertai **catatan** bila hasilnya turun kualitas, misalnya layanan LLM
  sedang tidak tersedia, agar pengguna tidak mengira hasilnya lengkap.

### 4. Generator Proposal TA (Chatbot Proposal AI)

Bagian ini adalah inti dari aplikasi: generator yang menyusun kerangka proposal sesuai
pedoman resmi konsentrasi **Artificial Intelligence**. Detail lengkapnya ada di
[Cara Kerja Generator Proposal](#cara-kerja-generator-proposal).

### 5. Panel Chat

- **Panel geser** di sisi kanan pada layar lebar (minimal 900 piksel) sehingga hasil
  pencarian tetap terlihat, atau **bottom sheet** pada layar sempit.
- Dua tombol mengambang di kanan bawah: Generator Proposal (warna aksen) dan Tanya AI
  (biru).
- Antarmuka **ChatGPT-like**: gelembung pesan riwayat yang bisa dihapus, kolom input
  dengan tombol kirim, dan status proses untuk jawaban yang memerlukan waktu lama.

---

## Tampilan Aplikasi

<img width="1918" height="901" alt="image" src="https://github.com/user-attachments/assets/cf7c2295-c774-4591-ac08-59932ee321f9" />


Saat panel chatbot dibuka, daftar hasil tetap terlihat di belakang. Inilah alasan panel
menggeser dari kanan, bukan memenuhi layar.

---

## Cara Kerja Generator Proposal

Generator Proposal TA mengikuti **pedoman resmi konsentrasi Artificial Intelligence UKP**.
Pengguna memberi ide atau judul, lalu generator **wajib bertanya** jalur proposal sebelum
menyusun draf.

### Langkah 1: Aplikasi selalu bertanya RISET atau PROYEK?

Segera setelah ide dikirim, generator membalas:

> **Apakah Tugas Akhir ini mengambil jalur RISET atau PROYEK?**
>
> - **RISET** untuk penelitian ilmiah: ada hipotesis, dataset, eksperimen, dan metrik
>   evaluasi model.
> - **PROYEK** untuk pengembangan aplikasi: ada solusi AI yang dapat dipakai pengguna,
>   diuji dengan metrik model dan UAT.
>
> Jawab dengan satu kata: **RISET** atau **PROYEK**.

Pengguna dapat menjawab dengan mengetik, atau menekan tombol pintas RISET dan PROYEK yang
muncul di panel. Aplikasi ini **tidak pernah menebak jalur dari isi ide**, karena kata
"aplikasi" atau "penelitian" sering muncul di ide tanpa menunjukkan jalur yang dimaksud.

### Langkah 2: Generator menyusun kerangka sesuai jalur

Berbeda dengan jawaban langsung, keluarannya berformat terstruktur. Setiap bagian punya
judul bernomor `## N. Judul Bagian`, sehingga dapat diuraikan menjadi kartu yang dapat
dibuka-tutup di antarmuka.

#### Jika jalur RISET (11 bagian)

1. **Judul**: maksimal 14 kata, berisi ringkasan tujuan penelitian.
2. **Latar Belakang Masalah**: konteks masalah, urgensi, ulasan singkat penelitian
   terdahulu, dan penegasan celah penelitian (research gap atau novelty).
3. **Rumusan Masalah**: apa yang dikerjakan dan pengukuran hasil yang realistis.
4. **Tujuan Penelitian**: penjelasan detail dari judul.
5. **Ruang Lingkup (Batasan Masalah)**: dataset, input, fitur (preprocessing,
   model atau algoritma, metrik pengukuran), dan output.
6. **Manfaat Penelitian**: manfaat ke depan.
7. **Landasan Teori**: konsep dan model atau algoritma yang digunakan.
8. **Penelitian Terdahulu / State-of-the-Art**: analisis mendalam metode, hasil,
   kelebihan, dan kekurangan studi sebelumnya.
9. **Metodologi Penelitian**: tahapan kerja yang disusun sebagai flowchart, sumber dan
   pengumpulan data, analisis dan perancangan, serta metode pengujian sistem dengan
   metrik spesifik.
10. **Jadwal Kegiatan**: draf Gantt chart.
11. **Daftar Pustaka**: minimal 10 referensi jurnal atau paper 5 tahun terakhir.

#### Jika jalur PROYEK (10 bagian)

1. **Latar Belakang Masalah**: masalah dunia nyata, ulasan singkat model AI relevan,
   dan inovasi aplikasi sebagai solusi.
2. **Rumusan Masalah**: apa yang dikerjakan dan bagaimana hasil model AI serta
   aplikasinya diukur.
3. **Tujuan Proyek**: penjelasan detail dari judul.
4. **Ruang Lingkup (Batasan Masalah)**: input, proses, output, model AI dan metrik
   pengujian, platform implementasi, dan batasan modul aplikasi.
5. **Manfaat Aplikasi**: manfaat bagi sasaran masyarakat atau mitra.
6. **Landasan Teori (Opsional)**: penjelasan library, framework, dan model.
7. **Penelitian Terdahulu / State-of-the-Art (Opsional)**: ulasan aplikasi serupa.
8. **Tahapan Pembuatan Perangkat Lunak**: tahapan kerja yang disusun sebagai flowchart,
   pengumpulan data uji dan training, analisa dan perancangan, serta pengujian sistem
   dengan metrik AI dan UAT oleh pengguna.
9. **Jadwal Kegiatan**: draf Gantt chart.
10. **Daftar Pustaka**: minimal 5 referensi dari dokumentasi web atau paper.

### Yang membuat draf ini berdasar data, bukan karangan

- **Grounding ke repository UKP.** Sebelum menulis, generator mengambil **5 TA yang paling
  mirip** dari ChromaDB dan menjadikannya sebagai konteks. Bagian Penelitian Terdahulu
**wajib**
  menyebut judul dan tahun TA yang benar-benar ada. Panel menampilkan catatan asal
  (provenance) berisi judul-judul tersebut, sehingga mahasiswa bisa langsung
  memverifikasi.
- **Sitasi inline.** Setiap klaim teknis diberi penanda `[1]`, `[2]`, dan seterusnya yang
  merujuk nomor pada Daftar Pustaka. Panel menampilkan daftar sitasi tiap bagian.
- **Angka bertanda rencana.** Metrik yang belum ada di data ditulis sebagai target,
  misalnya "target F1-score lebih besar atau sama dengan 0,85", bukan sebagai hasil yang
  sudah tercapai.
- **Menolak mengarang.** Instruksi sistem melarang mengarang judul TA, penulis, tahun,
  DOI, ISSN, atau venue yang tidak diketahui.
- **Draf bisa disalin.** Tombol **Salin draf** menyalin seluruh kerangka sebagai teks polos
  ke clipboard untuk disunting di dokumen.

---

## Arsitektur Teknis

| Lapisan | Teknologi |
| --- | --- |
| Frontend | Flutter Web (Dart), Material 3, state `provider` dan `ChangeNotifier` |
| Backend | Python 3 dan FastAPI, seluruhnya di dalam `api/` untuk routing Vercel |
| Basis data vektor | ChromaDB, in-memory secara default atau hosted lewat `CHROMA_HOST` |
| Embedding | Gemini `gemini-embedding-001`, atau embedder hashing lokal sebagai cadangan |
| LLM | Groq `openai/gpt-oss-120b`, dengan Gemini dan fallback ekstraktif |
| Hosting | Vercel, build statis Flutter dan satu fungsi Python serverless |
| Autentikasi | **Tidak ada.** Aplikasi publik, tanpa login |

**Tanpa autentikasi** adalah keputusan sadar: repository TA bersifat publik dan tidak ada
data per-pengguna yang perlu dilindungi.

### Alur RAG

```
Pencarian / Chat / Proposal
          |
          v
  Embedding query (provider yang sama dengan korpus, dipinjang per proses)
          |
          v
  ChromaDB query dengan where-clause (tahun, program, konsentrasi)
          |  n_results = max(15, 5 x 3), sehingga 5 teratas dipilih dari kandidat lebih luas
          v
  Penyaringan ulang di Python
          |
          v
  Konteks bernomor dan System Prompt (peran, batasan, aturan sitasi)
          |
          v
  Groq, lalu cadangan Gemini, lalu cadangan ringkasan ekstraktif
          |
          v
  Jawaban + matches + topics + notice
```

- **Korpora**: `api/data/ta_metadata.json` adalah sumber kebenaran untuk filter sidebar
  maupun teks yang di-embed, yaitu judul, penulis, kata kunci, konsentrasi, dan abstrak.
- **Konsistensi vektor**: penyedia embedding dipilih sekali per proses sehingga korpus dan
  query selalu berada di ruang dan dimensi yang sama.
- **Pemilihan penyedia bersifat sticky**: hanya bisa turun satu tingkat (Gemini ke hashing
  lokal), tidak pernah naik-naik, agar dimensi tidak berubah di tengah proses.
- **Penanganan kegagalan yang baik**: jika embedding gagal, `/api/search` turun ke
  pencocokan kata kunci literal. Jika LLM gagal, layanan mengembalikan ringkasan
  ekstraktif dengan `notice`. Tidak ada jalur yang mengembalikan HTTP 500.

### Stateless di Vercel

Fungsi Vercel stateless dan dapat didaur ulang kapan saja. Aplikasi tidak mengandalkan
memori proses, penulisan disk, background task, atau berkas yang dibuat saat runtime.
Korpus ChromaDB dibangun ulang secara idempoten dari dataset statis pada setiap cold
start. Percakapan proposal tidak disimpan di server: klien mengirim ulang percakapan
pendek pada setiap permintaan.

---

## Struktur Proyek

```
lib/                          # Aplikasi Flutter
  main.dart                   # entry point, provider, route
  config.dart                 # base URL API dan timeout
  theme/app_theme.dart        # warna, tipografi, skala spasi
  models/                     # thesis, search_result, search_filters,
                              # filter_options, chat_message, proposal_draft
  services/api_client.dart    # HTTP client dan ApiException
  state/                      # repository_search_controller, chat_controller,
                              # proposal_controller
  screens/                    # home_screen, publications_screen
  widgets/                    # search_header, filter_sidebar, thesis_card,
                              # chat_panel, proposal_panel, chat_overlay, state_views
api/                          # FastAPI serverless, root untuk Vercel
  main.py                     # entrypoint: app, CORS, router, lifespan
  routers/                    # meta, search, chat, proposal
  services/                   # config, embeddings, chroma_store, filters,
                              # llm_client, rag_service, proposal_prompt,
                              # proposal_service
  models/schemas.py           # skema pydantic
  data/ta_metadata.json       # dataset TA, 24 TA
  tests/                      # pytest
test/                         # flutter_test
web/                          # shell Flutter Web
vercel.json                   # konfigurasi build dan rewrite
```

Dokumentasi teknis lengkap, yaitu kontrak API, alur RAG, dan keputusan desain, ada di
[`ARCHITECTURE.md`](ARCHITECTURE.md). Aturan keras proyek ada di
[`CONSTRAINTS.md`](CONSTRAINTS.md).

---

## Menjalankan Secara Lokal

### Prasyarat

- **Flutter** dengan Dart SDK 3.4.0 atau lebih baru
- **Python** 3.10 atau lebih baru
- Kunci API bersifat opsional. Tanpa kunci, aplikasi tetap jalan dengan embedder lokal
  dan jawaban ekstraktif, hanya kualitasnya turun

### 1. Siapkan environment Python

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r api\requirements.txt
```

### 2. Siapkan konfigurasi

```powershell
Copy-Item .env.example .env
```

Isi `GROQ_API_KEY` untuk LLM dan `GEMINI_API_KEY` untuk embedding. Tanpa kunci pun
aplikasi tetap dapat dijalankan.

### 3. Jalankan backend

```powershell
.\.venv\Scripts\python.exe -m uvicorn api.main:app --reload --port 8000
```

Dokumentasi API interaktif tersedia di <http://127.0.0.1:8000/docs>, dan pemeriksaan
kesehatan di <http://127.0.0.1:8000/api/health>.

### 4. Jalankan frontend

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

> **Penting**: base URL API masuk lewat `--dart-define`, sehingga kode yang sama berjalan
> di laptop maupun di Vercel tanpa perubahan. Nilai defaultnya `/api`, yaitu path
> same-origin yang diarahkan `vercel.json` ke fungsi Python.

---

## Konfigurasi Environment

Seluruh kunci dibaca di sisi Python saja, dari environment variable. **Jangan pernah**
menaruh kunci di Dart, `vercel.json`, atau berkas yang di-commit. Salin `.env.example`
menjadi `.env`, yang sudah masuk `.gitignore`.

| Variabel | Kegunaan | Default |
| --- | --- | --- |
| `GROQ_API_KEY` | Kunci LLM Groq | kosong, LLM dimatikan |
| `GROQ_MODEL` | Model id di Groq | `openai/gpt-oss-120b` |
| `GEMINI_API_KEY` | Embedding dan cadangan LLM | kosong, embedder hashing lokal |
| `GEMINI_EMBED_MODEL` | Model embedding Gemini | `gemini-embedding-001` |
| `GEMINI_MODEL` | Model chat Gemini | `gemini-2.0-flash` |
| `CHROMA_HOST`, `CHROMA_PORT`, `CHROMA_COLLECTION` | ChromaDB hosted | kosong, memakai in-memory |
| `ALLOWED_ORIGINS` | Origin CORS, dipisah koma | `*` |

Kunci dikirim pada **header** (`Authorization` untuk Groq dan `x-goog-api-key` untuk
Gemini), tidak pernah pada query string, karena query string masuk log dan proxy.

---

## Daftar API Endpoint

| Method | Endpoint | Kegunaan |
| --- | --- | --- |
| `GET` | `/api/health` | Pemeriksaan health: status, jumlah record, provider LLM, jenis store |
| `GET` | `/api/filters` | Nilai unik untuk sidebar: tahun, program, konsentrasi, topik, tag |
| `GET` | `/api/search` | Browse saat `q` kosong, pencarian vektor saat `q` diisi |
| `POST` | `/api/chat` | Chatbot RAG dengan mode `similarity` atau `topics` |
| `POST` | `/api/proposal` | Generator proposal dengan `stage` `clarify` lalu `draft` |

### GET /api/search

Parameter kueri:

| Parameter | Tipe | Keterangan |
| --- | --- | --- |
| `q` | string | Kata kunci: judul, penulis, kata kunci, abstrak |
| `year` | int | Satu tahun, alternatif dari `years` |
| `years` | int, berulang | Contoh `?years=2024&years=2025` |
| `year_from`, `year_to` | int | Rentang inklusif slider tahun |
| `program` | string | Program studi |
| `concentration` | string | Konsentrasi |
| `topic` | string | Topik atau kata kunci, dicocokkan ke keywords dan tags |
| `limit` | int | 1 sampai 50, default 20 |
| `offset` | int | default 0 |

Contoh:

```bash
curl "http://127.0.0.1:8000/api/search?q=absensi%20siswa&year_from=2023&program=Informatika"
```

### POST /api/proposal

```jsonc
// permintaan
{
  "message": "deteksi kecurangan ujian online dengan eye tracking",
  "history": [{ "role": "user", "content": "..." }],
  "path": "riset",
  "concentration": "Artificial Intelligence"
}

// jawaban, jalur belum ditentukan
{
  "stage": "clarify",
  "answer": "Apakah Tugas Akhir ini mengambil jalur RISET atau PROYEK?",
  "path": null,
  "sections": [], "references": [], "grounded_on": [], "notice": null
}

// jawaban, draf berhasil dibuat
{
  "stage": "draft",
  "path": "riset",
  "sections": [{ "number": 1, "title": "Judul", "body": "...", "citations": [] }],
  "references": ["Smith, J. Eye tracking in exams. Journal of EdTech, 2023."],
  "grounded_on": ["Aplikasi Mobile untuk Absensi Siswa Berbasis QR Code"],
  "notice": null
}
```

---

## Pengujian

```powershell
flutter analyze
flutter test
.\.venv\Scripts\python.exe -m pytest api\tests
```

- **`flutter analyze`**: pemeriksaan statis, harus bebas issues.
- **`flutter test`**: pengujian widget memakai `FakeApiClient`, sehingga berjalan offline
  tanpa kunci dan tanpa jaringan.
- **`pytest api/tests`**: pengujian API yang berjalan **sepenuhnya offline**.
  `api/tests/conftest.py` mengosongkan kredensial provider setelah import, sehingga
  pengujian tidak pernah menyentuh Groq maupun Gemini dan tidak pernah membocorkan
  rahasia.

---

## Deployment ke Vercel

### Yang perlu diketahui sebelum mulai

- **Flutter tidak tersedia di build image Vercel.** Image itu berbasis Amazon Linux 2023
  dan hanya menyediakan Node, Python, dan Ruby. Karena itu `vercel.json` meng-clone SDK
  Flutter stable ke folder `flutter/` pada langkah install, lalu memanggil
  `flutter/bin/flutter` melalui path relatif tersebut. Build pertama akan memakan waktu
  beberapa menit tambahan.
- **Ukuran bundel fungsi Python hampir penuh.** `chromadb` menarik `onnxruntime`
  (sekitar 44 MB) dan `numpy` (sekitar 31 MB). Total dependensi runtime sekitar 219 MB
  Compared terhadap batas 250 MB untuk satu fungsi Python di Vercel. `onnxruntime`
  sebenarnya tidak dipakai, karena vektor selalu dikirim secara eksplisit.

### Langkah

1. Push repositori ini ke GitHub.
2. Import repositori ke Vercel sebagai project. **Framework Preset: Other.** Seluruh
   pengaturan build sudah ada di `vercel.json`:
   - `installCommand`: clone SDK Flutter stable ke `flutter/`
   - `buildCommand`: `flutter/bin/flutter pub get` lalu `flutter/bin/flutter build web --release`
   - `outputDirectory`: `build/web`
3. Tambahkan environment variable di **Project Settings**, lalu **Environment Variables**:
   - `GROQ_API_KEY` untuk LLM
   - `GEMINI_API_KEY` untuk embedding
   - `ALLOWED_ORIGINS` bila perlu membatasi origin
4. Deploy.

Alternatif tanpa dashboard: pasang Vercel CLI, lalu jalankan `vercel` di direktori ini dan
ikuti petunjuknya.

### Routing

Routing disusun sehingga `/api/*` diarahkan ke fungsi Python `api/main.py`, sedangkan
semua path lain jatuh ke `index.html`. Dengan begitu deep link dan refresh di
`/publications` tetap bekerja.

---

## Catatan Teknis dan Batasan

- **Tidak ada autentikasi.** Aplikasi ini publik. Tidak ada login, sesi, token, atau
  pelacakan pengguna.
- **Maksimal 50 hasil per halaman.** Semua hasil dipaginasi dan berbatas.
- **Jumlah record.** Dataset yang disertakan berisi 24 TA sebagai contoh. Untuk data
  produksi, ganti isi `api/data/ta_metadata.json` dengan metadata TA yang memang boleh
  dipublikasikan.
- **Kualitas bergantung pada kunci API.** Tanpa `GROQ_API_KEY`, generator proposal memakai
  fallback ekstraktif yang tidak menghasilkan kerangka lengkap. Panel menampilkan catatan
  `notice` agar pengguna tahu hasilnya tidak lengkap.
- **Batas durasi fungsi.** `vercel.json` menetapkan `maxDuration: 60` detik. Draf RISET
  penuh terukur sekitar 10 detik terhadap Groq, sehingga masih ada ruang yang lega.
- **Draf adalah bahan awal, bukan dokumen final.** Draf wajib disunting mahasiswa dan
  diperiksa dosen pembimbing sebelum diajukan.
- **Data pribadi.** Jangan memasukkan data yang belum dipublikasikan ke kolom pencarian
  maupun kolom chat.

---

## Lisensi

Proyek ini ditujukan untuk lingkungan internal universitas. Hubungi pengelola repository
untuk ketentuan penggunaan data TA.
