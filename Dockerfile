# syntax=docker/dockerfile:1
# Initialize device type args
# use build args in the docker build command with --build-arg="BUILDARG=true"
ARG USE_CUDA=false
ARG USE_OLLAMA=false
# Tested with cu117 for CUDA 11 and cu121 for CUDA 12 (default)
ARG USE_CUDA_VER=cu128
# any sentence transformer model; models to use can be found at https://huggingface.co/models?library=sentence-transformers
# Leaderboard: https://huggingface.co/spaces/mteb/leaderboard 
# for better performance and multilangauge support use "intfloat/multilingual-e5-large" (~2.5GB) or "intfloat/multilingual-e5-base" (~1.5GB)
# IMPORTANT: If you change the embedding model (sentence-transformers/all-MiniLM-L6-v2) and vice versa, you aren't able to use RAG Chat with your previous documents loaded in the WebUI! You need to re-embed them.
ARG USE_EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2
ARG USE_RERANKING_MODEL=""

# Tiktoken encoding name; models to use can be found at https://huggingface.co/models?library=tiktoken
ARG USE_TIKTOKEN_ENCODING_NAME="cl100k_base"

ARG BUILD_HASH=dev-build
# Override at your own risk - non-root configurations are untested
ARG UID=0
ARG GID=0

######## WebUI frontend ########
FROM --platform=$BUILDPLATFORM node:22-alpine3.20 AS build
ARG BUILD_HASH

WORKDIR /app

# to store git revision in build
RUN apk add --no-cache git

COPY package.json package-lock.json ./
RUN npm ci --force

COPY . .
ENV APP_BUILD_HASH=${BUILD_HASH}
RUN npm run build

######## WebUI backend ########
FROM python:3.11-slim-bookworm AS base

# Use args
ARG USE_CUDA
ARG USE_OLLAMA
ARG USE_CUDA_VER
ARG USE_EMBEDDING_MODEL
ARG USE_RERANKING_MODEL
ARG UID
ARG GID

## Basis ##
ENV ENV=prod \
    PORT=8080 \
    # pass build args to the build
    USE_OLLAMA_DOCKER=${USE_OLLAMA} \
    USE_CUDA_DOCKER=${USE_CUDA} \
    USE_CUDA_DOCKER_VER=${USE_CUDA_VER} \
    USE_EMBEDDING_MODEL_DOCKER=${USE_EMBEDDING_MODEL} \
    USE_RERANKING_MODEL_DOCKER=${USE_RERANKING_MODEL}

## Basis URL Config ##
ENV OLLAMA_BASE_URL="/ollama" \
    OPENAI_API_BASE_URL=""

## API Key and Security Config ##
ENV OPENAI_API_KEY="" \
    WEBUI_SECRET_KEY="" \
    SCARF_NO_ANALYTICS=true \
    DO_NOT_TRACK=true \
    ANONYMIZED_TELEMETRY=false

#### Other models #########################################################
## whisper TTS model settings ##
ENV WHISPER_MODEL="base" \
    WHISPER_MODEL_DIR="/app/backend/data/cache/whisper/models"

## RAG Embedding model settings ##
ENV RAG_EMBEDDING_MODEL="$USE_EMBEDDING_MODEL_DOCKER" \
    RAG_RERANKING_MODEL="$USE_RERANKING_MODEL_DOCKER" \
    SENTENCE_TRANSFORMERS_HOME="/app/backend/data/cache/embedding/models"

## Tiktoken model settings ##
ENV TIKTOKEN_ENCODING_NAME="cl100k_base" \
    TIKTOKEN_CACHE_DIR="/app/backend/data/cache/tiktoken"

## Hugging Face download cache ##
ENV HF_HOME="/app/backend/data/cache/embedding/models"

## Torch Extensions ##
# ENV TORCH_EXTENSIONS_DIR="/.cache/torch_extensions"

#### Other models ##########################################################

WORKDIR /app/backend

ENV HOME=/root
# Create user and group if not root
RUN if [ $UID -ne 0 ]; then \
    if [ $GID -ne 0 ]; then \
    addgroup --gid $GID app; \
    fi; \
    adduser --uid $UID --gid $GID --home $HOME --disabled-password --no-create-home app; \
    fi

RUN mkdir -p $HOME/.cache/chroma
RUN echo -n 00000000-0000-0000-0000-000000000000 > $HOME/.cache/chroma/telemetry_user_id

# Make sure the user has access to the app and root directory
RUN chown -R $UID:$GID /app $HOME

# Install common system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git build-essential pandoc gcc netcat-openbsd curl jq \
    python3-dev \
    libreoffice-core libreoffice-common \
    libreoffice-writer libreoffice-calc libreoffice-impress libreoffice-draw \ 
    ffmpeg libsm6 libxext6 \
    # MS fonts installer
    #fontconfig ttf-mscorefonts-installer \
    #fonts-crosextra-carlito fonts-crosextra-caladea \
    && rm -rf /var/lib/apt/lists/*

    
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    fonts-3270 fonts-adf-accanthis fonts-adf-baskervald fonts-adf-berenis fonts-adf-gillius fonts-adf-ikarius fonts-adf-irianis fonts-adf-libris fonts-adf-mekanus fonts-adf-oldania fonts-adf-romande fonts-adf-switzera fonts-adf-tribun fonts-adf-universalis fonts-adf-verana fonts-aksharyogini2 fonts-alee fonts-ancient-scripts fonts-aoyagi-kouzan-t fonts-aoyagi-soseki fonts-arabeyes fonts-arkpandora fonts-arphic-bkai00mp fonts-arphic-bsmi00lp fonts-arphic-gbsn00lp fonts-arphic-gkai00mp fonts-arphic-ukai fonts-arphic-uming fonts-atarismall fonts-averia-gwf fonts-averia-sans-gwf fonts-averia-serif-gwf fonts-babelstone-han fonts-babelstone-modern fonts-baekmuk fonts-bebas-neue fonts-beng fonts-beng-extra fonts-beteckna fonts-blankenburg fonts-bpg-georgian fonts-breip fonts-cabin fonts-cabinsketch fonts-cantarell fonts-cardo fonts-century-catalogue fonts-circos-symbols fonts-cmu fonts-cns11643-kai fonts-cns11643-sung fonts-comfortaa fonts-comic-neue fonts-croscore fonts-crosextra-caladea fonts-crosextra-carlito fonts-cwtex-docs fonts-cwtex-fs fonts-cwtex-heib fonts-cwtex-kai fonts-cwtex-ming fonts-cwtex-yen fonts-dancingscript fonts-ddc-uchen fonts-dejavu fonts-dejavu-core fonts-dejavu-extra fonts-dejima-mincho fonts-deva fonts-deva-extra fonts-dkg-handwriting fonts-dosis fonts-droid-fallback fonts-dseg fonts-dustin fonts-dzongkha fonts-ebgaramond fonts-ebgaramond-extra fonts-ecolier-court fonts-ecolier-lignes-court fonts-eeyek fonts-elusive-icons fonts-emojione fonts-entypo fonts-essays1743 fonts-evertype-conakry fonts-f500 fonts-fantasque-sans fonts-fanwood fonts-farsiweb fonts-femkeklaver fonts-firacode fonts-font-awesome fonts-freefarsi fonts-freefont-otf fonts-freefont-ttf fonts-gargi fonts-georgewilliams fonts-gfs-artemisia fonts-gfs-baskerville fonts-gfs-bodoni-classic fonts-gfs-complutum fonts-gfs-didot fonts-gfs-didot-classic fonts-gfs-gazis fonts-gfs-neohellenic fonts-gfs-olga fonts-gfs-porson fonts-gfs-solomos fonts-gfs-theokritos fonts-glewlwyd fonts-go fonts-goudybookletter fonts-gubbi fonts-gujr fonts-gujr-extra fonts-guru fonts-guru-extra fonts-hack fonts-hack-otf fonts-hack-ttf fonts-hack-web fonts-hanazono fonts-horai-umefont fonts-hosny-amiri fonts-hosny-thabit fonts-humor-sans fonts-inconsolata fonts-indic fonts-ipaexfont fonts-ipaexfont-gothic fonts-ipaexfont-mincho fonts-ipafont fonts-ipafont-gothic fonts-ipafont-mincho fonts-ipafont-nonfree-jisx0208 fonts-ipafont-nonfree-uigothic fonts-ipamj-mincho fonts-isabella fonts-johnsmith-induni fonts-jsmath fonts-junction fonts-junicode fonts-jura fonts-kacst fonts-kacst-one fonts-kalapi fonts-kanjistrokeorders fonts-karla fonts-kaushanscript fonts-khmeros fonts-khmeros-core fonts-kiloji fonts-klaudia-berenika fonts-knda fonts-komatuna fonts-konatu fonts-kouzan-mouhitsu fonts-kristi fonts-lao fonts-larabie-deco fonts-larabie-straight fonts-larabie-uncommon fonts-lato fonts-ldco fonts-league-spartan fonts-leckerli-one fonts-levien-museum fonts-levien-typoscript fonts-lexi-gulim fonts-lexi-saebom fonts-lg-aboriginal fonts-liberation fonts-liberation2 fonts-lindenhill fonts-linex fonts-linuxlibertine fonts-lklug-sinhala fonts-lmodern fonts-lobster fonts-lobstertwo fonts-lohit-beng-assamese fonts-lohit-beng-bengali fonts-lohit-deva fonts-lohit-deva-marathi fonts-lohit-deva-nepali fonts-lohit-gujr fonts-lohit-guru fonts-lohit-knda fonts-lohit-mlym fonts-lohit-orya fonts-lohit-taml fonts-lohit-taml-classical fonts-lohit-telu fonts-lyx fonts-maitreya fonts-manchufont fonts-materialdesignicons-webfont fonts-mathematica fonts-mathjax fonts-mathjax-extras fonts-meera-taml fonts-migmix fonts-mikachan fonts-misaki fonts-mlym fonts-mmcedar fonts-moe-standard-kai fonts-moe-standard-song fonts-mona fonts-monapo fonts-monlam fonts-monoid fonts-mononoki fonts-motoya-l-cedar fonts-motoya-l-maruberi fonts-mph-2b-damase fonts-mplus fonts-nafees fonts-nakula fonts-nanum fonts-nanum-coding fonts-nanum-eco fonts-nanum-extra fonts-naver-d2coding fonts-navilu fonts-noto fonts-noto-cjk fonts-noto-cjk-extra fonts-noto-color-emoji fonts-noto-hinted fonts-noto-mono fonts-noto-unhinted fonts-ocr-a fonts-ocr-b fonts-octicons fonts-oflb-asana-math fonts-oflb-euterpe fonts-okolaks fonts-oldstandard fonts-open-sans fonts-opendin fonts-opendyslexic fonts-opensymbol fonts-oradano-mincho-gsrr fonts-orya fonts-orya-extra fonts-oxygen fonts-pagul fonts-paktype fonts-pecita fonts-play fonts-powerline fonts-prociono fonts-quattrocento fonts-radisnoir fonts-ricty-diminished fonts-roboto fonts-roboto-fontface fonts-roboto-hinted fonts-roboto-slab fonts-roboto-unhinted fonts-rufscript fonts-sahadeva fonts-sambhota-tsugring fonts-sambhota-yigchung fonts-samyak fonts-samyak-deva fonts-samyak-gujr fonts-samyak-mlym fonts-samyak-orya fonts-samyak-taml fonts-sarai fonts-sawarabi-gothic fonts-sawarabi-mincho fonts-senamirmir-washra fonts-seto fonts-sil-abyssinica fonts-sil-andika fonts-sil-andika-compact fonts-sil-andikanewbasic fonts-sil-annapurna fonts-sil-charis fonts-sil-charis-compact fonts-sil-dai-banna fonts-sil-doulos fonts-sil-doulos-compact fonts-sil-ezra fonts-sil-galatia fonts-sil-gentium fonts-sil-gentium-basic fonts-sil-gentiumplus fonts-sil-gentiumplus-compact fonts-sil-harmattan fonts-sil-lateef fonts-sil-mondulkiri fonts-sil-mondulkiri-extra fonts-sil-nuosusil fonts-sil-padauk fonts-sil-scheherazade fonts-sil-sophia-nubian fonts-sil-taiheritagepro fonts-sil-zaghawa-beria fonts-sipa-arundina fonts-smc fonts-smc-anjalioldlipi fonts-smc-chilanka fonts-smc-dyuthi fonts-smc-karumbi fonts-smc-keraleeyam fonts-smc-manjari fonts-smc-meera fonts-smc-rachana fonts-smc-raghumalayalamsans fonts-smc-suruma fonts-smc-uroob fonts-stix fonts-symbola fonts-takao fonts-takao-gothic fonts-takao-mincho fonts-takao-pgothic fonts-taml fonts-taml-tamu fonts-taml-tscu fonts-telu fonts-telu-extra fonts-teluguvijayam fonts-texgyre fonts-thai-tlwg fonts-thai-tlwg-otf fonts-thai-tlwg-ttf fonts-thai-tlwg-web fonts-tibetan-machine fonts-tiresias fonts-tlwg-garuda fonts-tlwg-garuda-otf fonts-tlwg-garuda-ttf fonts-tlwg-kinnari fonts-tlwg-kinnari-otf fonts-tlwg-kinnari-ttf fonts-tlwg-laksaman fonts-tlwg-laksaman-otf fonts-tlwg-laksaman-ttf fonts-tlwg-loma fonts-tlwg-loma-otf fonts-tlwg-loma-ttf fonts-tlwg-mono fonts-tlwg-mono-otf fonts-tlwg-mono-ttf fonts-tlwg-norasi fonts-tlwg-norasi-otf fonts-tlwg-norasi-ttf fonts-tlwg-purisa fonts-tlwg-purisa-otf fonts-tlwg-purisa-ttf fonts-tlwg-sawasdee fonts-tlwg-sawasdee-otf fonts-tlwg-sawasdee-ttf fonts-tlwg-typewriter fonts-tlwg-typewriter-otf fonts-tlwg-typewriter-ttf fonts-tlwg-typist fonts-tlwg-typist-otf fonts-tlwg-typist-ttf fonts-tlwg-typo fonts-tlwg-typo-otf fonts-tlwg-typo-ttf fonts-tlwg-umpush fonts-tlwg-umpush-otf fonts-tlwg-umpush-ttf fonts-tlwg-waree fonts-tlwg-waree-otf fonts-tlwg-waree-ttf fonts-tomsontalks fonts-tuffy fonts-ubuntu fonts-ubuntu-console fonts-ubuntu-font-family-console fonts-ubuntu-title fonts-ukij-uyghur fonts-umeplus fonts-unfonts-core fonts-unfonts-extra fonts-unikurdweb fonts-uralic fonts-urw-base35 fonts-vlgothic fonts-vollkorn fonts-wine fonts-woowa-hanna fonts-wqy-microhei fonts-wqy-zenhei fonts-yanone-kaffeesatz fonts-yozvox-yozfont fonts-yozvox-yozfont-antique fonts-yozvox-yozfont-cute fonts-yozvox-yozfont-edu fonts-yozvox-yozfont-new-kana fonts-yozvox-yozfont-standard-kana fonts-yrsa-rasa \
    && rm -rf /var/lib/apt/lists/*


# install python dependencies
COPY --chown=$UID:$GID ./backend/requirements.txt ./requirements.txt

RUN pip3 install --no-cache-dir uv && \
    if [ "$USE_CUDA" = "true" ]; then \
    # If you use CUDA the whisper and embedding model will be downloaded on first use
    pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/$USE_CUDA_DOCKER_VER --no-cache-dir && \
    uv pip install --system -r requirements.txt --no-cache-dir && \
    python -c "import os; from sentence_transformers import SentenceTransformer; SentenceTransformer(os.environ['RAG_EMBEDDING_MODEL'], device='cpu')" && \
    python -c "import os; from faster_whisper import WhisperModel; WhisperModel(os.environ['WHISPER_MODEL'], device='cpu', compute_type='int8', download_root=os.environ['WHISPER_MODEL_DIR'])"; \
    python -c "import os; import tiktoken; tiktoken.get_encoding(os.environ['TIKTOKEN_ENCODING_NAME'])"; \
    else \
    pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu --no-cache-dir && \
    uv pip install --system -r requirements.txt --no-cache-dir && \
    python -c "import os; from sentence_transformers import SentenceTransformer; SentenceTransformer(os.environ['RAG_EMBEDDING_MODEL'], device='cpu')" && \
    python -c "import os; from faster_whisper import WhisperModel; WhisperModel(os.environ['WHISPER_MODEL'], device='cpu', compute_type='int8', download_root=os.environ['WHISPER_MODEL_DIR'])"; \
    python -c "import os; import tiktoken; tiktoken.get_encoding(os.environ['TIKTOKEN_ENCODING_NAME'])"; \
    fi; \
    chown -R $UID:$GID /app/backend/data/

# Install Ollama if requested
RUN if [ "$USE_OLLAMA" = "true" ]; then \
    date +%s > /tmp/ollama_build_hash && \
    echo "Cache broken at timestamp: `cat /tmp/ollama_build_hash`" && \
    curl -fsSL https://ollama.com/install.sh | sh && \
    rm -rf /var/lib/apt/lists/*; \
    fi

# copy embedding weight from build
# RUN mkdir -p /root/.cache/chroma/onnx_models/all-MiniLM-L6-v2
# COPY --from=build /app/onnx /root/.cache/chroma/onnx_models/all-MiniLM-L6-v2/onnx

# copy built frontend files
COPY --chown=$UID:$GID --from=build /app/build /app/build
COPY --chown=$UID:$GID --from=build /app/CHANGELOG.md /app/CHANGELOG.md
COPY --chown=$UID:$GID --from=build /app/package.json /app/package.json

# copy backend files
COPY --chown=$UID:$GID ./backend .

EXPOSE 8080

HEALTHCHECK CMD curl --silent --fail http://localhost:${PORT:-8080}/health | jq -ne 'input.status == true' || exit 1

# Minimal, atomic permission hardening for OpenShift (arbitrary UID):
# - Group 0 owns /app and /root
# - Directories are group-writable and have SGID so new files inherit GID 0
RUN set -eux; \
    chgrp -R 0 /app /root || true; \
    chmod -R g+rwX /app /root || true; \
    find /app -type d -exec chmod g+s {} + || true; \
    find /root -type d -exec chmod g+s {} + || true

USER $UID:$GID

ARG BUILD_HASH
ENV WEBUI_BUILD_VERSION=${BUILD_HASH}
ENV DOCKER=true

CMD [ "bash", "start.sh"]
