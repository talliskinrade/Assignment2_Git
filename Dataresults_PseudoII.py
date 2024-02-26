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
Data3 = 0
Data4 = 0
Data5 = 0
Data6 = 0


seqDone = False

hypothetical_list = [200, 179, 41, -4, 65, 2, 75, 83, 160, 52, 174, 174,
                      76, 156, 175, 181, 195, 167, 174, 131, 241
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

while counter < numWords:
   
    ## the following are specific edge cases, if the
    ## max lies in the first or last 3 of the dataset
    ## need also to write edge cases where numwords is less than 7.
    
    if counter == 0:
        Register0 = 0;
        Register1 = 0;
        Register2 = 0;
        
    elif counter == 1:
        Register0 = 0;
        Register1 = 0;
        Register2 = hypothetical_list[counter-1];
        
    elif counter == 2:
        Register0 = 0;
        Register1 = hypothetical_list[counter-2];
        Register2 = hypothetical_list[counter-1];
    
    
    else:
        Register0 = hypothetical_list[counter-3]
    
    
        Register1 = hypothetical_list[counter-2]
    
    
        Register2 = hypothetical_list[counter-1]
    
    
    Data3 = hypothetical_list[counter]
    
    if Data3 > maxValue:
        
        third_last = False
        second_last = False
        last = False
        middle = False
        
        
        maxValue = Data3
        maxIndex = counter
        print("maxValue = ", maxValue)
        print("maxIndex = ", maxIndex)
        
        Data0 = Register0
        Data1 = Register1
        Data2 = Register2
        
        mux_choice = numWords - counter
        
## this ensures that even if the max value is at the very end of the
## list, it will still output the correct bytes, i.e. if 14 was the max and
##very last bit, it would output [3,7,9,14,0,0,0]
        
        if mux_choice >= 4:
            # i.e. if mux_choice is 00 (overflow)
            middle = True
        elif mux_choice ==3:
            third_last = True
        elif mux_choice == 2:
            second_last = True
        elif mux_choice == 1:
            last = True
        elif mux_choice == 0:
            middle = True
            ## should never happen anyway. make sure of this!
            
        
        
        
    
    
        print(middle, third_last, second_last, last)
            
    if middle == True:
            
        if counter == maxIndex +1:
            Data4 = hypothetical_list[counter]
            print('Data4 = ', Data4, ", ",counter)
            
        elif counter == maxIndex +2:
            Data5 = hypothetical_list[counter]
            print('Data5 = ', Data5, ", ",counter)
            
        elif counter == maxIndex +3:
                
            Data6 = hypothetical_list[counter]
            print('Data6 = ', Data6, ", ",counter)
    
    elif third_last == True:
        if counter == maxIndex +1:
            Data4 = hypothetical_list[counter]
            print('Data4 = ', Data4, ", ",counter)
            
        elif counter == maxIndex +2:
            Data5 = hypothetical_list[counter]
            print('Data5 = ', Data5, ", ",counter)
        Data6 = 0
    
    elif second_last == True:
        if counter == maxIndex +1:
            Data4 = hypothetical_list[counter]
            print('Data4 = ', Data4, ", ",counter)
        Data5 = 0
        Data6 = 0
        
    elif last == True:
        Data4 = 0
        Data5 = 0
        Data6 = 0
        
        
        
     
    #print('counter = ', counter)
    counter +=1



DataResults = [Data0,Data1,Data2,maxValue,Data4,Data5,Data6]
seqDone = True
print('SeqDone = ', seqDone)
print("DataResults = ", DataResults)




