#!/usr/bin/Rscript

argLoc <- 1;

usage <- function(){
  cat("usage: ./seqmat.r <fasta file> <repeat unit size> [options]\n");
  cat("\nOther Options:\n");
  cat("-help               : Only display this help message\n");
  cat("-type (png/pdf/svg) : Image type (default 'png')\n");
  cat("-ps <factor>        : Magnification factor for points\n");
  cat("-title <string>     : Title for image\n");
  cat("-prefix <string>    : Prefix for output file (default 'sequence_')\n");
  cat("-solid              : Make colours solid (not translucent)\n");
  cat("-spiral             : Add a white spiral to the plot\n");
  cat("-rev                : reverse the spiral direction\n");
  cat("-min                : Set minimum circle radius\n");
  cat("-max                : Set maximum circle radius\n");
  cat("-nokey              : Remove key\n");
  cat("-size <x>x<y>       : Image size (default 1200x1200 for png, 12x12 for PDF)\n");
  cat("-col (ef|cb)        : Colour palette (electrophoresis [default], colour-blind)\n");
 cat("\n");
}

fileName <- "";
filePrefix <- "sequence";
rptSize <- -1;
type <- "png";
sizeX <- -1;
sizeY <- -1;
colType <- "ef";
pointFactor <- 1;
revSeq <- FALSE;
useKey <- TRUE;
solid <- FALSE;
minRad <- 0.3;
maxRad <- 1.0;
spiral <- FALSE;
plotTitle <- "";

seqRange <- FALSE;

if(length(commandArgs(TRUE)) == 0){
      usage();
      quit(save = "no", status=0);
}

while(!is.na(commandArgs(TRUE)[argLoc])){
    arg <- commandArgs(TRUE)[argLoc];
    argLoc <- argLoc + 1;
    if(arg == "-help"){
      usage();
      quit(save = "no", status=0);
    } else if(arg == "-size"){
        arg <- unlist(strsplit(commandArgs(TRUE)[argLoc], "x"));
        argLoc <- argLoc + 1;
        sizeX <- as.numeric(arg[1]);
        sizeY <- as.numeric(arg[2]);
    } else if(arg == "-ps"){
        arg <- commandArgs(TRUE)[argLoc];
        pointFactor <- as.numeric(arg);
        argLoc <- argLoc + 1;
    } else if(arg == "-title"){
        arg <- commandArgs(TRUE)[argLoc];
        plotTitle <- arg;
        argLoc <- argLoc + 1;
    } else if(arg == "-prefix"){
        arg <- commandArgs(TRUE)[argLoc];
        filePrefix <- arg;
        argLoc <- argLoc + 1;
    } else if(arg == "-min"){
        arg <- commandArgs(TRUE)[argLoc];
        minRad <- as.numeric(arg);
        argLoc <- argLoc + 1;
    } else if(arg == "-max"){
        arg <- commandArgs(TRUE)[argLoc];
        maxRad <- as.numeric(arg);
        argLoc <- argLoc + 1;
    } else if(arg == "-type"){
        arg <- commandArgs(TRUE)[argLoc];
        argLoc <- argLoc + 1;
        type <- arg;
    } else if(arg == "-rev"){
        revSeq <- TRUE;
    } else if(arg == "-solid"){
        solid <- TRUE;
    } else if(arg == "-spiral"){
        spiral <- TRUE;
    } else if(arg == "-nokey"){
        useKey <- FALSE;
    } else if(arg == "-col"){
        arg <- commandArgs(TRUE)[argLoc];
        argLoc <- argLoc + 1;
        colType <- arg;
    } else {
        if(grepl(":\\-?[0-9]+\\-[0-9]+$",arg)){
            prefix <- sub(":[^:]+$","",arg);
            suffix <- sub("^.*:","",arg);
            arg <- prefix;
            r1 <- as.numeric(sub("^(.*)\\-(.*)$", "\\1", suffix));
            r2 <- as.numeric(sub("^(.*)\\-(.*)$", "\\2", suffix));
            seqRange <- c(r1,r2);
        }
        if(file.exists(arg)){
            fileName <- arg;
        } else if ((rptSize == -1) && grepl("^[0-9]+$", arg)){
            rptSize <- as.numeric(arg);
        } else {
            cat("Error: Argument '", arg,
                "' is not understood by this program\n\n", sep="");
            usage();
            quit(save = "no", status=0);
        }
    }
}

if(rptSize == -1){
    cat("Error: repeat unit size has not been specified\n\n");
    usage();
    quit(save = "no", status=0);
}

inLines <- readLines(fileName);

cat("Reading from file:",fileName,"...");
inName <- substring(inLines[1],2);
if(substring(inLines[1],1,1) == "@"){
    ## assume FASTQ files are one line per sequence (four lines per record)
    inLines <- inLines[c(-seq(3,length(inLines), by=4),
                         -seq(4,length(inLines), by=4))];
}
inSeq <- c(A=1, C=2, G=3, T=4, N=5, "-"=5,
           a=1, c=2, g=3, t=4, n=5)[unlist(strsplit(paste(inLines[-1],collapse=""),""))];
cat(" done\n");

if(seqRange[1] != FALSE){
    if(seqRange[2] > length(inSeq)){
        inSeq <- c(inSeq, rep(5,seqRange[2] - length(inSeq)));
    }
    if(seqRange[1] < 0){
        inSeq <- c(rep(5,-seqRange[1]+1), inSeq);
        inSeq <- inSeq[(seqRange[1]:seqRange[2]) + -seqRange[1] + 1];
    } else {
        inSeq <- inSeq[seqRange[1]:seqRange[2]];
    }
}

if(revSeq){
    inSeq <- rev(inSeq);
}

if(type == "png"){
    if(sizeX == -1){
        sizeX <- 1200;
    }
    if(sizeY == -1){
        sizeY <- 1200;
    }
} else if((type == "pdf") || (type == "svg")){
    if(sizeX == -1){
        sizeX <- 12;
    }
    if(sizeY == -1){
        sizeY <- 12;
    }
}

colPal <-
    if(colType == "cb"){
        c("#006400","#0000FF","#FFD700","#FF6347","#D3D3D3");
    } else {
        c("#006400","#0000FF","#FFD700","#8B0000","#D3D3D3");
    }

cat("Creating matrix plot...");
if(type == "png"){
    png(sprintf("%s_matrix.png", filePrefix), width=sizeX, height=sizeY,
        pointsize=24 * sizeX/1000);
} else if(type == "pdf"){
    pdf(sprintf("%s_matrix.pdf", filePrefix), width=sizeX, height=sizeY,
        pointsize=16 * sizeX/10);
} else if(type == "svg"){
    print(16 * sizeX/1000);
    svg(sprintf("%s_matrix.svg", filePrefix), width=sizeX, height=sizeY,
        pointsize=16 * sizeX/10);
}
lis <- length(inSeq);
numLines <- floor(lis/rptSize + 1);
inSeq <- c(inSeq,rep(5,rptSize));
subSeq <- inSeq[1:(numLines*rptSize)];
par(mar=c(0.5,5,1,0.5), mgp=c(3.5,1,0));
image(x=1:rptSize, y=1:numLines-1, matrix(subSeq,nrow=rptSize),
      main=sprintf("%s%s (%0.3f kb, %d bases / line)", sub(" .*$","",inName),
                   ifelse(seqRange[1] == FALSE,"",
                          paste0(": ",seqRange[1]," .. ",seqRange[2])),
                   lis/1000, rptSize), ylab="Base location",
      cex.main=0.8, xaxt="n", yaxt="n", useRaster=TRUE,
      col=colPal);
axis(2, at=round(seq(0, numLines, length.out=20)),
     labels=round(seq(0, numLines, length.out=20)) * rptSize+1,
     las=2, cex.axis=1);
dummy <- dev.off();

numLoops <- (length(subSeq) / rptSize);
##startCount <- rptSize / 1.2;
startCount <- rptSize;
startRadius <- minRad;
endRadius <- maxRad;
##loopIncrement <- ((rptSize * 1.2) - (rptSize / 1.2)) / numLoops;
cat(" done\n");

cat("Creating spiral plot...");
if(type == "png"){
    png(sprintf("%s_spiral.png", filePrefix), width=max(sizeX,sizeY),
        height=max(sizeX,sizeY), pointsize=24 * max(sizeX,sizeY)/1000);
} else if(type == "pdf"){
    pdf(sprintf("%s_spiral.pdf", filePrefix), width=max(sizeX,sizeY),
        height=max(sizeX,sizeY),
        pointsize=16 * max(sizeX,sizeY)/10);
} else if(type == "svg"){
    svg(sprintf("%s_spiral.svg", filePrefix), width=max(sizeX,sizeY),
        height=max(sizeX,sizeY),
        pointsize=16 * max(sizeX,sizeY)/10);
}
if(nchar(plotTitle) > 0){
    par(mar=c(2.5,2.5,2.5,2.5));
} else {
    par(mar=c(0.5,1.5,2.5,1.5));
}
plot(NA, xlim=c(-1,1), ylim=c(-1,1), axes=FALSE, ann=FALSE);
mtext(sprintf("%s%s\n(%0.3f kb, %d bases / ring)", sub(" .*$","",inName),
              ifelse(seqRange[1] == FALSE,"",
                     paste0(": ",seqRange[1]," .. ",seqRange[2])),
              lis/1000, rptSize), side=3, cex=1, line=0);
mtext(plotTitle, side=1, cex=2, line=0);
## Pre-population plot variables
## integrate(2*pi*r,r=startRadius..endRadius)
## => pi((endRadius)²-(startRadius)²)
dTot <- pi*(endRadius^2 - startRadius^2); ## total "distance" travelled
theta <- seq(0, (numLoops+1+2/rptSize) * 2*pi,
             length.out=(length(subSeq)+rptSize+3)); ## traversed angle
deg <- (theta / (2*pi)) * 360;
r <- seq(sqrt(startRadius), sqrt(endRadius),
         length.out=length(subSeq)+rptSize+2)^2; ## path radius
s <- pi * (r^2 - startRadius^2); ## traversed distance at each pos
ds <- c(s[2],diff(s)); ## distance difference at each pos
##print(cbind(seq(1,length(r),by=rptSize),r[seq(1,length(r),by=rptSize)]));
cr <- 2*pi*r / numLoops; ## circumference of one loop

## par(mfrow=c(4,1));
## plot(s, main="s");
## plot(r, main="r");
## plot(deg, main="deg");
## plot(theta, main="theta");

ss <- rev(seq_along(subSeq))+1;
d <- rptSize;

polygon(x=c(rbind(
            r[ss-1+0] * cos(theta[ss-1+0]),
            r[ss+0+0] * cos(theta[ss+0+0]),
            r[ss+0+d] * cos(theta[ss+0+d]),
            r[ss-1+d] * cos(theta[ss-1+d]), NA)),
        y=c(rbind(
            r[ss-1+0] * sin(theta[ss-1+0]),
            r[ss+0+0] * sin(theta[ss+0+0]),
            r[ss+0+d] * sin(theta[ss+0+d]),
            r[ss-1+d] * sin(theta[ss-1+d]), NA)),
        ##lwd = 5 * sqrt(r)[ss], lend=(ifelse(numLoops>20,1,0)),
        ##border="#00000040",
        border = paste0(colPal[rev(subSeq)],ifelse(solid,"FF","A0")),
        col = paste0(colPal[rev(subSeq)],ifelse(solid,"FF","A0")),
        pch=15, cex=sqrt(r)[ss] * (13/log(numLoops)) * pointFactor);
if(spiral){
    sps <- rev(seq(0,length(subSeq)+d))+1;
    points(x=r[sps] * cos(theta[sps]), y=r[sps] * sin(theta[sps]),
           type="l", col="white", lwd=3*sizeX/1000);
}
if(useKey){
    legend("bottomright", legend=c("A","C","G","T"), inset=0.05,
           fill=colPal[1:4], cex=0.71, ncol=2);
}
invisible(dev.off());
cat(" done\n");
