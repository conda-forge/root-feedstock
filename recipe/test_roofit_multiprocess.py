import ROOT

x = ROOT.RooRealVar("x", "x", -10, 10)
mean = ROOT.RooRealVar("mean", "mean of gaussian", 1, -10, 10)
sigma = ROOT.RooRealVar("sigma", "width of gaussian", 3, 0.1, 10)

gauss = ROOT.RooGaussian("gauss", "gaussian PDF", x, mean, sigma)

data = gauss.generate(x, 10000)  # ROOT.RooDataSet

# Use the new RooFit multiprocessing for parallelization
# See https://root.cern.ch/doc/master/classRooAbsPdf.html#ab0721374836c343a710f5ff92a326ff5
# This raises an exception if RooFit multiprocessing is not available
result = gauss.fitTo(data, PrintLevel=-1, Parallelize=2, Save=True)

# status zero means successful fit
assert result.status() == 0
