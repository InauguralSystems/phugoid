from fractions import Fraction as F
from decimal import Decimal, getcontext
getcontext().prec=65
A=[[-19.161767101927296,0.,5.7042862816381046e-05],[-163.06389089427998,-8.426380004936119,0.],[-.503629171275742,-.5574470847550791,0.]]
def solve(a,b):
 t=[[F(x) for x in r]+[F(v)] for r,v in zip(a,b)]
 for i in range(3):
  for j in range(i+1,3):
   f=t[j][i]/t[i][i]; t[j]=[x-f*y for x,y in zip(t[j],t[i])]
 x=[F(0)]*3
 for i in reversed(range(3)): x[i]=(t[i][3]-sum(t[i][j]*x[j] for j in range(i+1,3)))/t[i][i]
 return x
x=solve(A,[2.962668320672937,.00842352456126917,-2.03281790110409e-06])
for v in x: print('exact binary-input solve:',Decimal(v.numerator)/Decimal(v.denominator),'nearest:',float(v))
J=[[-19.17889741,-.00045853,5.70428628107e-05],[-162.9641397,-8.42637994,-1.0236e-10],[-.5029380223,-.55744708477,-7.244e-13]]
cols=[solve(J,[int(i==j) for i in range(3)]) for j in range(3)]
gamma=100*2**-53/(1-100*2**-53)
r=[1e-13+gamma*v for v in [6,70,.001]]
b=[sum(abs(float(cols[j][i]))*2*r[j] for j in range(3)) for i in range(3)]
print('two solves forward difference bounds alpha,de,thrust:',b)
print('state bounds u,w,q,theta:',abs(.0152)*b[0],279.1*b[0],0,b[0])
