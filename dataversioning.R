setwd("/home/pawel/projects/dataversioning")

# Design
# - 1 commit = zmiana w 1 pliku z danymi
# - 1 branch = 1 plik z danymi
# - konflikt przy push/pull: nalezy wykonac rename; potem ktos powinien recznie wykonac aktualizacje danych
# - wysłanie na github / gitlab / bitbucket pozwala na wygodne porównywanie co w danych uległo zmianie
# - idea: po co uczyć wszystkich gita? wniosek z Roche i Dropbox approach; narzędzia już są, brakuje przybliżenia masom
# - pakiet poddaj dyskusji z Markiem. Prowadzi Tech Talki i może dać cenne uwagi
# - na Tech Talku opowiadaj o tym jak o jakimś obcym pakiecie, a na koniec że jesteś autorem
# - idea: można dopisać obsługe czytania dowolnego typu danych (feather, json, image, geojson, yaml, ...)
# - nazwy commitow pozwalaja przesledzic czym to bylo wczesniej, np kiedy byl renameData()

repo <- "/home/pawel/projects/dataversioning/repo/"
data <- mtcars

branchExists <- function(name) {
  setwd(repo)
  code <- system(paste("git branch | grep -w", name), ignore.stdout = T)
  return (code == 0)
}

saveData <- function(data, name, type) {
  setwd(repo)
  commit <- NULL
  if (type == "csv") {
    fileName <- "data.csv"
    if (branchExists(name)) {
      system(paste("git checkout", name))
      print(paste0("Switched to existing branch `", name, "`"))
    } else {
      system(paste("git checkout --orphan", name))
      system("git rm --cached $(git ls-files)")
      print(paste0("Created new branch `", name, "`"))
    }
    system("git clean -fd && echo 'Cleaned repo'")
    write.csv(data, file.path(repo, fileName))
    system(paste("git add", fileName))
    system(paste0("git commit -m '", name, "'"))
    commit <- system("git rev-parse HEAD", intern = T)
  }
  return (commit)
}

renameData <- function(from, to) {
  setwd(repo)
  if (branchExists(to)) {
    message(paste0("Can't rename dataset - `", to, "` already exists"))
  } else {
    system(paste("git branch -m", from, to))
  }
}

availableData <- function(name = NULL, n = 10) {
  setwd(repo)
  if (is.null(name)) {
    localBranches <- system("git branch", intern = T)
    localBranches <- stringr::str_replace_all(localBranches, "\\*", "")
    localBranches <- stringr::str_replace_all(localBranches, " ", "")
    system("git fetch -p", ignore.stdout = T, ignore.stderr = T)
    remoteBranches <- system("git branch -r", intern = T) 
    remoteBranches <- stringr::str_replace_all(remoteBranches, " ", "")
    remoteBranches <- sapply(remoteBranches, function(x) tail(stringr::str_split(x, "/")[[1]], n = 1))
    return (list(local = localBranches, remote = remoteBranches))
  } else {
    system(paste("git checkout", name), ignore.stdout = T, ignore.stderr = T)
    commits <- system(paste("git rev-list HEAD -n", n), intern = T)
    return (commits)
  }
}

readData <- function(name, type, commit = NULL) {
  setwd(repo)
  data <- NULL
  if (is.null(commit)) {
    stop("You must provide `commit` hash")
  }
  if (!branchExists(name)) {
    stop(paste0("Can't find dataset `", to, "`. Did you run pullData()?"))
  } else {
    if (type == "csv") {
      fileName <- "data.csv"
      system(paste("git checkout", commit, fileName))
      data <- read.csv(fileName)
    }
  }
  return (data)
}

pushData <- function() {
  setwd(repo)
  branches <- availableData()
  for (name in branches$local) {
    cat(paste0("Pushing `", name, "`...\n"))
    code <- system(paste("git push origin", name), ignore.stdout = T, ignore.stderr = F)
    if (code == 0) {
      cat("OK\n")
    } else {
      stop(paste0("Failed! Probably newer version of `", name, "` exists. Rename it and then push."))
    }
  }
}

pullData <- function() { # iteracyjnie po availableData
  setwd(repo) 
  branches <- availableData()
  for (name in branches$remote) {
    cat(paste0("Pulling `", name, "`...\n"))
    if (branchExists(name)) {
      system(paste("git checkout", name))
    } else {
      system(paste0("git checkout --track origin/", name))
    }
    code <- system(paste("git pull origin", name), ignore.stdout = T, ignore.stderr = F)
    if (code == 0) {
      cat("OK\n")
    } else {
      system("git reset --hard")
      stop(paste0("Failed! Probably you updated `", name, "` locally. Rename it and then pull."))
    }
  }
}

syncData <- function() {
  pullData()
  pushData()
}


saveData(mtcars, name = "what", type = "csv")
renameData(from = "cars3", to = "iris")
readData("what", "csv", "abcd")
availableData()
syncData()
