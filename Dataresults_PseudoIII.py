# -*- coding: utf-8 -*-
"""
Spyder Editor

This is a temporary script file.
"""


counter = 0
maxIndex = 0
maxValue =0
DataResults = []
Register0 = 0
Register1 = 0
Register2 = 0
Data0 = 0
Data1 = 0
Data2 = 0
Data3 = 0
maxValue = 0
Data4 = 0
Data5 = 0
Data6 = 0

Reg6 = 0
Reg5 = 0
Reg4 = 0
Reg3 = 0
Reg2 = 0
Reg1 = 0
Reg0 = 0




seqDone = False

hypothetical_list = [31, 179, 41, -4, 65, 2, 75, 83, 271, 52, 174, 174,
                      76, 156, 175, 181, 195, 167, 174, 291, 252
                      ]
# hypothetical_list = [279, 179, 41, -4, 65, 2, 75, 83, 160, 52, 174, 174,
#                       76, 156, 175, 181, 195, 167, 174, 131, 241, 159, 62
#                       ]
# hypothetical_list = [3,7,  9, 14, 2, 8,4,5]
# hypothetical_list = [3,7,  9, 14, 2, 8]
# hypothetical_list = [3,7,  9, 14, 2]
# hypothetical_list = [3,7,  9, 14]
# hypothetical_list = [14]


numWords = len(hypothetical_list)
print("numwords = ", numWords)



while counter < numWords+3:
   
    ## the following are specific edge cases, if the
    ## max lies in the first or last 3 of the dataset
    ## need also to write edge cases where numwords is less than 7.
    if counter >= numWords:
        Reg6 = 0
    ##could maybe simplify this, instead of using a comparator, just use
    ##some kind of permanent enable.
    else:
        Reg6 = hypothetical_list[counter]
    
    Reg0 = Reg1
    Reg1 = Reg2
    Reg2 = Reg3
    Reg3 = Reg4
    Reg4 = Reg5
    Reg5 = Reg6
        
    print("Reg0 = ", Reg0)
    
    
    
    
    
    if Reg3 > maxValue:
        
               
        
        maxValue = Reg3
        maxIndex = counter - 3
        print("maxValue = ", maxValue)
        print("maxIndex = ", maxIndex)
        
        
        Data0 = Reg0
        Data1 = Reg1
        Data2 = Reg2
        Data4 = Reg4
        Data5 = Reg5
        Data6 = Reg6
        DataResults = [Data0,Data1,Data2,maxValue,Data4, Data5,Data6]
        print(DataResults)
    
    counter +=1




seqDone = True
print('SeqDone = ', seqDone)
print("DataResults = ", DataResults)
print("maxIndex = ", maxIndex)
print("maxValue = ", maxValue)




