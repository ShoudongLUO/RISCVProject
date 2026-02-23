#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
#include <cmath>
#include <iomanip>
#include <bitset>

using namespace std;

// --- Simplified Event Classes based on your code ---

class TEVENT {
public:
   double time;
   double var[4];
   double ttime[2];
   double tstat[2];
   long long tnt[2];
   int clear(){time=0; var[0]=var[1]=0; ttime[0]=ttime[1]=0; tstat[0]=tstat[1]=-1; tnt[0]=tnt[1]=0; return 0;}
   TEVENT(){clear();}
};

class Event {
public:
  unsigned int headerbuf;
  unsigned int header;
  unsigned int data[6]; // 30-30-30-7-7-7
  int id[2];
  int clear(int level=0){if(level>=1)headerbuf=0; header=0; for(int i=0;i<6;i++)data[i]=0; id[0]=id[1]=0; return 0;}
  Event(){clear(1);}

  // Core logic from your original code
  long long translatecode(int stat, double dt, double sclock){
      double dbit=1./sclock*1000; 
      long long nb=dt/dbit+0.5;
      return nb;
  }

  int loadbuf(int bstat, long long bsize, long long &rsize){
      rsize=bsize;
      if((bstat!=0 && bstat!=1) || bsize<=0) return -2;
      static const unsigned int mheader=0b10101010101010101;
      static const int HEADER_LEN = 17;
      static const unsigned MASK = (1u << HEADER_LEN) - 1;

      if(header==0){
        while(rsize>0){
          headerbuf=(((headerbuf << 1) | bstat) & MASK);
          rsize--;
          if(headerbuf==mheader){header=headerbuf; headerbuf=0; break;}
        }
      }
      if(header){
        while(rsize>0 && id[0]<6){
          data[id[0]]=((data[id[0]] << 1) | bstat);
          rsize--;
          id[1]++;
          bool idflag=0;
          if(id[0]>=0 && id[0]<3){if(id[1]>=30)idflag=1;}
          else {if(id[1]>=7)idflag=1;}
          
          if(idflag){
            id[0]++; id[1]=0;
          }
        }
        if(id[0]>=6) return 1; // Packet Full
        else return 0;
      }
      else return -1;
  }
};

class Select{
 public:
    TEVENT *tev;
    Event *ev[2];
    ofstream f_out[2]; // Output files for Ch1 and Ch2

    Select(){
        tev = new TEVENT();
        ev[0] = new Event();
        ev[1] = new Event();
        f_out[0].open("ch1_vectors.txt");
        f_out[1].open("ch2_vectors.txt");
    }

    ~Select(){
        f_out[0].close();
        f_out[1].close();
    }

    // Helper to print 128-bit hex compatible with Verilog
    void print_packet(int ch) {
        // We need to construct a 128-bit value from data[0]..data[5]
        // Mapping based on your Verilog code:
        // raw_fine[0]   = data_in[127:98]; (30 bits)
        // raw_fine[1]   = data_in[97:68];  (30 bits)
        // raw_fine[2]   = data_in[67:38];  (30 bits)
        // raw_coarse[0] = data_in[37:31];  (7 bits)
        // raw_coarse[1] = data_in[30:24];  (7 bits)
        // raw_coarse[2] = data_in[23:17];  (7 bits)
        // [16:0]        = Padding/Zeros

        // Use __int128 for easy shifting (Standard in GCC/Clang)
        unsigned __int128 packet = 0;
        
        packet |= ((unsigned __int128)(ev[ch]->data[0] & 0x3FFFFFFF)) << 98;
        packet |= ((unsigned __int128)(ev[ch]->data[1] & 0x3FFFFFFF)) << 68;
        packet |= ((unsigned __int128)(ev[ch]->data[2] & 0x3FFFFFFF)) << 38;
        packet |= ((unsigned __int128)(ev[ch]->data[3] & 0x7F)) << 31;
        packet |= ((unsigned __int128)(ev[ch]->data[4] & 0x7F)) << 24;
        packet |= ((unsigned __int128)(ev[ch]->data[5] & 0x7F)) << 17;

        // Print High 64 bits then Low 64 bits
        unsigned long long high = (unsigned long long)(packet >> 64);
        unsigned long long low  = (unsigned long long)(packet);
        
        f_out[ch] << setfill('0') << setw(16) << hex << high 
                  << setw(16) << low << endl;
    }

    bool processev(double t, double ch1, double ch2){
        double pstat[2];
        pstat[0] = (ch1 < 0.13) ? 0 : 1;
        pstat[1] = (ch2 < 0.13) ? 0 : 1;
        
        static const double samdt = 0.16;
        static const double serfeq = 720.;

        for(int i=0; i<2; i++){
            if(pstat[i] != tev->tstat[i]){
                if(tev->tstat[i] != -1){
                    long long nb = ev[i]->translatecode(tev->tstat[i], tev->tnt[i]*samdt, serfeq);
                    long long rsize;
                    int rstat = ev[i]->loadbuf(tev->tstat[i], nb, rsize);
                    
                    // Bit error handling similar to your code
                    if(rstat == -3){ ev[i]->clear(); rstat=ev[i]->loadbuf(tev->tstat[i], nb, rsize); }
                    
                    if(rstat >= 1){ 
                        // Packet is FULL! Print it to file.
                        print_packet(i);
                        
                        ev[i]->clear();
                        if(rsize >= 1) ev[i]->loadbuf(tev->tstat[i], rsize, rsize);
                    }
                    tev->tnt[i] = 0;
                }
                tev->tstat[i] = pstat[i];
            }
            tev->tnt[i]++;
        }
        tev->time = t;
        return 0;
    }

    bool startsWithNumber(const std::string& s) {
        size_t i = 0;
        return (i < s.size() && (isdigit(s[i]) || s[i] == '-' || s[i] == '+'));
    }

    bool readfile(const std::string& fname) {
        std::ifstream file(fname.c_str());
        if (!file.is_open()) { cerr << "Error opening " << fname << endl; return 1; }
        
        cout << "Processing " << fname << "..." << endl;
        string line;
        bool startReading = false;
        while (getline(file, line)) {
            if (startsWithNumber(line)) { startReading = true; break; }
        }
        if(!startReading) return 1;

        int endflag = -1;
        tev->clear(); ev[0]->clear(); ev[1]->clear();

        do {
            double t, ch1, ch2;
            stringstream ss(line);
            string item;
            if (getline(ss, item, ',')) t = stod(item); else continue;
            if (getline(ss, item, ',')) ch1 = stod(item); else continue;
            if (getline(ss, item, ',')) ch2 = stod(item); else continue;
            
            processev(t, ch1, ch2);

        } while(getline(file, line));
        
        file.close();
        return 0;
    }
};

int main(){
    Select *sel = new Select();
    // Use the file path from your code
    string path = "Tek000_010_ALL_laser10.csv"; // CHANGE THIS to your local path
    sel->readfile(path);
    cout << "Done! Vectors generated in ch1_vectors.txt and ch2_vectors.txt" << endl;
    return 0;
}